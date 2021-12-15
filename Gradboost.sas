*------------------------------------------------------------*;
* Macro Variables for input, output data and files;
  %let dm_datalib       =;                 /* Libref associated with the CAS training table */
  %let dm_output_lib    = &dm_datalib;     /* Libref associated with the output CAS tables */
  %let dm_data_caslib   =;                 /* CASLIB associated with the training table */
  %let dm_output_caslib = &dm_data_caslib; /* CASLIB associated with the output tables */
  %let dm_inputTable=;  /* Input Table */
  %let dm_memName=_input_MB9PMLLQIHP4DT3BAE92SA57;
  %let dm_memNameNLit='_input_MB9PMLLQIHP4DT3BAE92SA57'n;
  %let dm_lib     = WORK;
  %let dm_folder  = %sysfunc(pathname(work));
*------------------------------------------------------------*;
*------------------------------------------------------------*;
  * Preparing the training data for modeling;
*------------------------------------------------------------*;
%macro dm_rejected;
'MaxHR'n 'RestingECG'n
%mend dm_rejected;
%global dm_num_rejected;
%let dm_num_rejected = 2 ;

data &dm_datalib..&dm_memname/ SESSREF=&_SESSREF_;
   set &dm_datalib..&dm_inputTable;

/*************************************************/
/*              Interval Variables               */
/*************************************************/
If
  ('Cholesterol'n>=0.1)
then M_FILTER=0;
Else M_FILTER=1;
Length M_FILTER 8;
Label M_FILTER='Filtered Indicator';

if 
'M_FILTER'n ne 1
 then output;
   drop %dm_rejected;
run;
*------------------------------------------------------------*;
  * Training for gradboost;
*------------------------------------------------------------*;
*------------------------------------------------------------*;
  * Initializing Variable Macros;
*------------------------------------------------------------*;
%macro dm_assessforbias;
%mend dm_assessforbias;
%global dm_num_assessforbias;
%let dm_num_assessforbias = 0;
%macro dm_unary_input;
%mend dm_unary_input;
%global dm_num_unary_input;
%let dm_num_unary_input = 0;
%macro dm_interval_input;
'Age'n 'Cholesterol'n 'Oldpeak'n 'RestingBP'n
%mend dm_interval_input;
%global dm_num_interval_input;
%let dm_num_interval_input = 4 ;
%macro dm_binary_input;
'ExerciseAngina'n 'FastingBS'n 'Sex'n
%mend dm_binary_input;
%global dm_num_binary_input;
%let dm_num_binary_input = 3 ;
%macro dm_nominal_input;
'ChestPainType'n 'ST_Slope'n
%mend dm_nominal_input;
%global dm_num_nominal_input;
%let dm_num_nominal_input = 2 ;
%macro dm_ordinal_input;
%mend dm_ordinal_input;
%global dm_num_ordinal_input;
%let dm_num_ordinal_input = 0;
%macro dm_class_input;
'ChestPainType'n 'ExerciseAngina'n 'FastingBS'n 'Sex'n 'ST_Slope'n
%mend dm_class_input;
%global dm_num_class_input;
%let dm_num_class_input = 5 ;
%macro dm_segment;
%mend dm_segment;
%global dm_num_segment;
%let dm_num_segment = 0;
%macro dm_id;
%mend dm_id;
%global dm_num_id;
%let dm_num_id = 0;
%macro dm_text;
%mend dm_text;
%global dm_num_text;
%let dm_num_text = 0;
%macro dm_strat_vars;
'HeartDisease'n
%mend dm_strat_vars;
%global dm_num_strat_vars;
%let dm_num_strat_vars = 1 ;
*------------------------------------------------------------*;
  * Initializing Macro Variables *;
*------------------------------------------------------------*;
  %let dm_data_outfit = &dm_lib..outfit;
  %let dm_file_scorecode = &dm_folder/scorecode.sas;
  %let dm_caslibOption =;
  data _null_;
     if index(symget('dm_data_caslib'), '(') or index(symget('dm_data_caslib'), ')' ) or (symget('dm_data_caslib')=' ') then do;
        call symput('dm_caslibOption', ' ');
     end;
     else do;
        call symput('dm_caslibOption', 'caslib="'!!ktrim(symget('dm_data_caslib'))!!'"');
     end;
  run;


*------------------------------------------------------------*;
  * Component Code;
*------------------------------------------------------------*;
proc gradboost data=&dm_datalib..&dm_memnameNlit(&dm_caslibOption)
     earlystop(tolerance=0 stagnation=5 minimum=NO metric=MCR)
     binmethod=QUANTILE
     maxbranch=2
     nomsearch(maxcategories=128)
     assignmissing=USEINSEARCH minuseinsearch=1
     minleafsize=5
     seed=12345
     printtarget
  ;
  partition rolevar='_PartInd_'n (TRAIN='1' VALIDATE='0' TEST='2');
  autotune  bestmodelactionhistory=&dm_output_lib..histtable historysyntax=LUA useparameters=CUSTOM tuningparameters=(
     lasso(LB=0 UB=10 INIT=0)
     learningrate(LB=0.01 UB=1 INIT=0.1)
     ntrees(LB=20 UB=150 INIT=100)
     ridge(LB=0 UB=10 INIT=1)
     samplingrate(LB=0.1 UB=1 INIT=0.5)
     maxdepth(LB=1 UB=6 INIT=6)
     numbin(LB=20 UB=100 INIT=50)
     vars_to_try(LB=1 UB=9 INIT=9)
     )
     searchmethod=GA objective=KS maxtime=3600
     maxevals=50 maxiters=5 popsize=10
     targetevent='1'
  ;
  target 'HeartDisease'n / level=nominal;
  input %dm_interval_input / level=interval;
  input %dm_binary_input %dm_nominal_input %dm_ordinal_input %dm_unary_input  / level=nominal;
  ods output
     VariableImportance   = &dm_lib..varimportance
     Fitstatistics        = &dm_data_outfit
     PredProbName = &dm_lib..PredProbName
     PredIntoName = &dm_lib..PredIntoName
     TunerResults = &dm_lib..tuneresults
     BestConfiguration = &dm_lib..tunebest(drop=name)
  ;
  savestate rstore=&dm_output_lib.._MB9PMLLQIHP4DT3BAE92SA57_ast;
run;
