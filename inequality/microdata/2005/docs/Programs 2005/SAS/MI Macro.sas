/**********************************************************************/
/* PROGRAM NAME:  CE MACROS.SAS                                       */
/* LOCATION: 	C:\SAS       					                      */
/*                                                                    */
/* FUNCTION: CALCULATE MEAN AND SE USING BRR (FOR NUMERIC VARIABLES)  */
/*           PERFORM OLS AND LOGISTIC REGRESSIONS USING BRR           */
/*           FOR COLLECTION YEAR ESTIMATES                            */
/*                                                                    */
/*    CALCULATE MEANS AND VARIANCES FOR UNWEIGHTED DATA               */
/*    PERFORM OLS AND LOGISTIC REGRESSIONS FOR UNWEIGHTED DATA        */
/*                                                                    */
/* WRITTEN BY:  SALLY REYES                                           */
/*                                                                    */
/* MODIFICATIONS:                                                     */
/* DATE-      MODIFIED BY-                                            */
/* -----      ------------                                            */
/* 12/01/05   SALLY REYES                                             */
/**********************************************************************/

/**********************************************************************/
/*          The following macros do not annualize expenditures        */
/**********************************************************************/
/*						HOW TO USE THIS MACROS						  */
/**********************************************************************/

/*
OPTIONS PAGENO=1 NOCENTER NODATE;								
* INCLUDE MACRO ;
%INCLUDE "C:\SAS\CE MACROS.SAS";

* READ YOUR DATA SET ;
* NAME AND VALUES FOR REPLICATE WEIGHTS AND FINLWT21 SHOULD NOT BE CHANGED ;
LIBNAME IN "C:\SAS\";							
DATA CEDATA;																
SET IN.CEDATA;																
RUN;																	

* CALL THE MACROS ;

      %MEAN_VARIANCE(DSN = CEDATA, 
  				  FORMAT = , 
			 USE_WEIGHTS = YES,
				   BYVAR = REGION, 
				ANALVARS = PENSIONX INTEARNX, 
			IMPUTED_VARS = PENSION1-PENSION5 INTEARN1-INTEARN5,
                      CL = 90, 
					  DF = RUBIN87,
				  TITLE1 = Testing the macro program,
				  TITLE2 = for CEDATA,
				 XOUTPUT = );

	  %PROC_REG(DSN = CEDATA, 
  			 FORMAT = REGION $REGION., 
		USE_WEIGHTS = NO,
		      BYVAR = REGION,
		   DEP_VARS = ZTOTAL, 
		   IND_VARS = AGE_REF, 
	   IMPUTED_VARS = PENSION1-PENSION5 INTEARN1-INTEARN5,
			     DF = RUBIN87,
		     TITLE1 = Testing the Regression program,
			 TITLE2 = for the CEDATA,
		    XOUTPUT = );

      %PROC_LOGISTIC(DSN = CEDATA, 
  				  FORMAT = , 
			 USE_WEIGHTS = YES,
		           BYVAR = ,
				DEP_VARS = GENDER SEX, 
				IND_VARS = NORTHEAST MIDWEST WEST, 
			IMPUTED_VARS = PENSION1-PENSION5 INTEARN1-INTEARN5, 
			          DF = RUBIN87,
			  SORT_ORDER = INTERNAL, 
			   CLASSVARS = ,
				  TITLE1 = Testing the Logistic program,
                  TITLE2 = for the CEDATA,
				 XOUTPUT = );
*/

OPTIONS PAGENO=1 NOCENTER NODATE formdlim = '-' NONOTES;

/**********************************************************************/
/* READ DATASET      			                                      */
/**********************************************************************/
%MACRO READ_DATA;
OPTIONS PAGENO=1 NOCENTER NODATE;
%IF %UPCASE(&USE_WEIGHTS) = YES %THEN %DO;
	DATA MYDATA(DROP=WTREP01-WTREP09);
	SET &DSN.;
	FORMAT &FORMAT.;
	/*CONVERT MISSING WEIGHTS TO ZERO*/
	ARRAY A(45) WTREP01-WTREP44 FINLWT21;
	ARRAY B(45) WTREP1-WTREP45;
	 	DO I=1 TO 45;
	  IF A(I)=.B THEN A(I)=0;
	  ELSE IF A(I)=. THEN A(I)=0;
	  B(I)=A(I);
	  DROP I; 
	 END;
	RUN;
%END;
%ELSE %IF %UPCASE(&USE_WEIGHTS) = NO %THEN %DO;
	DATA MYDATA;
	SET &DSN.;
	FORMAT &FORMAT.;
	RUN;
%END;
%MEND;

/**********************************************************************/
/* GET SAMPLE SIZE    			                                      */
/**********************************************************************/
%MACRO PROC_FREQ;
* SPECIFY SORTING ORDER IF BY VARIABLES PRESENT;

%GLOBAL BYV;

%IF (%SUPERQ(BYVAR) NE ) %THEN %DO;
PROC SORT DATA=MYDATA;
BY &BYVAR.;
RUN;
%END;

DATA COUNT_SS(KEEP=SAMPLE_SIZE &BYVAR. Count);
SET MYDATA;
SAMPLE_SIZE = 'RECORDS';
Count=1;
RUN;
/* GET THE SAMPLE SIZE */

%IF (%SUPERQ(BYVAR) NE ) %THEN %DO;
%LET BYVARS = %SCAN(&BYVAR., 1, ' ');
%COUNT_VARS(&BYVAR.,DELIM=%STR( ));
	%LET BYV = &N_VARS.;
		%IF &BYV. GE 2 %THEN %DO;
			%DO BV=2 %TO &BYV.;
 			   %LET BYVR = %SCAN(&BYVAR., &BV, ' ');
				%LET BYVARS = &BYVARS.*&BYVR.;
			%END;
		%END;

PROC FREQ DATA=COUNT_SS NOPRINT;
TABLES &BYVARS./OUT=CTGPS(KEEP = &BYVAR. Count) LIST;
RUN;

PROC SORT DATA=CTGPS;
BY &BYVAR.;
RUN;

/* GET GROUPS NUMBERS */
data CTGPS;
set CTGPS;
 Group=_n_;  
run;

DATA MYDATA;
MERGE MYDATA CTGPS(DROP=COUNT);
BY &BYVAR.;
RUN;

PROC PRINT DATA=CTGPS ;
TITLE1 "Consumer Expenditure Survey";
TITLE2 "Sample size for collection year estimates";
TITLE3 "Dataset &DSN. By &BYVAR.";
VAR &BYVAR. Count;
ID GROUP;
RUN;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE CTGPS;
QUIT;
%END;
%ELSE %DO;
PROC FREQ DATA=COUNT_SS;
TITLE1 "Consumer Expenditure Survey";
TITLE2 "Sample size for collection year estimates";
TITLE3 "Dataset &DSN.";
TABLES SAMPLE_SIZE;
RUN;
%END;

PROC MEANS DATA=COUNT_SS NOPRINT;
BY &BYVAR.; 
VAR COUNT;
OUTPUT OUT=SS N=SS;
RUN;

DATA SS(DROP=_TYPE_ _FREQ_);
SET SS;
COUNT=1;
RUN;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE COUNT_SS;
QUIT;
%MEND;

/**********************************************************************/
/* COUNT THE NUMBER OF VARIABLES    			                      */
/**********************************************************************/
%MACRO COUNT_VARS(STR,DELIM=%STR( ));
%GLOBAL N_VARS;
%LOCAL N STR DELIM;
%LET N=1;
%DO %WHILE(%LENGTH(%SCAN(&STR,&N,&DELIM)) GT 0);
  %LET N=%EVAL(&N + 1);
%END;
%LET N_VARS=%EVAL(&N - 1);
%MEND;

/**********************************************************************/
/* PRINT OUTPUT DATASET WITH MEANS AND VARIANCES                      */
/* CREATE DATASETS WITH FINAL RESULTS                                 */
/* CREATE DATASET FOR BY GROUP COMPARISONS                            */
/**********************************************************************/
%MACRO PRINT;
/* PRINT OUTPUT DATASET */
%IF (%SUPERQ(XOUTPUT) = YES) OR "&ANALVARS." NE "&IMPUTED_VARS." %THEN %DO;

%IF %UPCASE(&USE_WEIGHTS) = YES %THEN 
	%LET TITLE6 = Mean and SE using the BRR method of variance estimation;
    %ELSE %IF %UPCASE(&USE_WEIGHTS) = NO %THEN 
    %LET TITLE6 = Unweighted Mean and SE;

PROC PRINT DATA=A SPLIT='*' UNIFORM;
    TITLE1 &TITLE1.;
	TITLE2 &TITLE2.;
    TITLE3 &TITLE3.;
	TITLE4 &TITLE4.;
	TITLE5 &TITLE5.;
    TITLE6 &TITLE6.;
	TITLE7 &TITLE7.;
ID &BYVAR. VARIABLE;
VAR MEAN SE VARIANCE RSE;
LABEL 
    VARIABLE = " Variable"
	MEAN     = " Mean"
    SE       = " Standard*    Error*     (SE)"
    VARIANCE = " Variance"
	RSE      = " Relative* Standard*    Error* ((SE/Mean)x100)"
    ;
RUN;

PROC PRINT DATA=A SPLIT='*' UNIFORM;
    TITLE1 &TITLE1.;
	TITLE2 &TITLE2.;
    TITLE3 &TITLE3.;
	TITLE4 &TITLE4.;
	TITLE5 &TITLE5.;
	TITLE6 "&CI.";
	TITLE7 &TITLE7.;
ID &BYVAR. VARIABLE;
VAR MEAN DFC CI_LOW CI_HIGH;
LABEL 
    VARIABLE = " Variable"
	MEAN     = " Mean"
	DFC      = "Degrees of * Freedom"
    ;
RUN;
%END;

%IF "&ANALVARS." NE "&IMPUTED_VARS." %THEN %DO;
DATA ANALVARS
	(KEEP=VARIABLE MEAN VARIANCE SE RSE &BYVAR. ALPHA DFC CI_LOW CI_HIGH);
RETAIN VARIABLE &BYVAR. MEAN SE VARIANCE RSE DFC ALPHA CI_LOW CI_HIGH; 
SET A;
RUN;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE A;
QUIT;

/* CREATE TRANSPOSE DATASET TO MAKE COMPARISONS BY BY_GROUPS */
%IF &BYVAR. NE  %THEN %DO;
proc sort data=TMEANS;
by _name_ &BYVAR.;
run;

data TMEANS(drop=&BYVAR.);
set TMEANS;
run;

PROC TRANSPOSE DATA=TMEANS PREFIX=GP OUT=TYAV;
BY _name_;
RUN;
%END;
%END;
%MEND;

/**********************************************************************/
/* CALCULATE WEIGHTED MEANS AND VARIANCES     			              */
/**********************************************************************/
%MACRO WT_MEAN_VARIANCE(ANALVARS=);
/* CHECK TYPE OF VARIABLE OF INTEREST */

PROC CONTENTS DATA = MYDATA (KEEP = &ANALVARS.) NOPRINT
  OUT = VARTYPE;
RUN;

%LET CHARS = ;

PROC SQL NOPRINT;
 SELECT NAME INTO: CHARS SEPARATED BY ' '
 FROM VARTYPE WHERE TYPE = 2;
QUIT;
/* IF VARIABLE IS NOT NUMERIC PRINT ERROR MESSAGE AND END PROGRAM */
/* ELSE CONTINUE WITH PROGRAM */

%IF &CHARS NE %THEN %DO;
%PUT ERROR: Variable &CHARS. in list does not match type prescribed for this list.;
%END;
%ELSE %DO;
/* RUN PROC MEANS 45 TIMES */

%DO I = 1 %TO 45;
PROC MEANS DATA=MYDATA NOPRINT;
BY &BYVAR.; 
VAR &ANALVARS.;
WEIGHT WTREP&I.;
OUTPUT OUT=M&I. MEAN=&ANALVARS.;
RUN;

PROC APPEND BASE=ALL_MEANS DATA=M&I.;
RUN;
%END;

DATA ALL_MEANS(DROP=_TYPE_ _FREQ_);
SET ALL_MEANS;
RUN;
* SPECIFY SORTING ORDER IF BY VARIABLES PRESENT;

%IF (%SUPERQ(BYVAR) NE ) %THEN %DO;
PROC SORT DATA=ALL_MEANS;
BY &BYVAR.;
RUN;
%END;
/* TRANSPOSE ALL THE VARIABLES */

PROC TRANSPOSE DATA=ALL_MEANS PREFIX=YBAR OUT=TMEANS;
BY &BYVAR.;
RUN;

DATA TMEANS;
SET TMEANS;
  ARRAY YBARS(44) YBAR1-YBAR44;
    DO I = 1 TO 44;
      IF YBARS(I)=. THEN YBARS(I)=0;
      DROP I; 
    END; 
RUN;
/* CALCULATE SE FOR THE MEAN */

DATA A;
  SET TMEANS;
  Variable = _NAME_;
  ARRAY YBARS(44) YBAR1-YBAR44;
  ARRAY SQDIFF(44) SQDIFF1-SQDIFF44;
    DO I = 1 TO 44;
      SQDIFF(I) = (YBARS(I) - YBAR45)**2;
      DROP I; 
    END; 
  MEAN = YBAR45;
  VARIANCE = SUM(OF SQDIFF(*))/44;
  SE = SQRT(VARIANCE); /* HORIZONTAL SUM */
  IF MEAN NE 0 THEN RSE= (SE/MEAN)*100;
  ELSE RSE = .;
  DFC = 44;
  ALPHA = &ALPHA.;
  T = ABS(TINV(ALPHA,DFC));
  CI_HIGH = MEAN+(SE*T);
  CI_LOW = MEAN-(SE*T);
RUN;

PROC SORT DATA=A;
BY _NAME_;
RUN;

%PRINT;
%END;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE VARTYPE M1-M45 ALL_MEANS TMEANS;
QUIT;
%MEND;

/**********************************************************************/
/* CALCULATE UNWEIGHTED MEANS AND VARIANCES   			              */
/**********************************************************************/
%MACRO UNWT_MEAN_VARIANCE(ANALVARS=);
/* CHECK TYPE OF VARIABLE OF INTEREST */
PROC CONTENTS DATA = MYDATA (KEEP = &ANALVARS.) NOPRINT
  OUT = VARTYPE;
RUN;

%LET CHARS = ;

PROC SQL NOPRINT;
 SELECT NAME INTO: CHARS SEPARATED BY ' '
 FROM VARTYPE WHERE TYPE = 2;
QUIT;
/* IF VARIABLE IS NOT NUMERIC PRINT ERROR MESSAGE AND END PROGRAM */
/* ELSE CONTINUE WITH PROGRAM */

%IF &CHARS NE %THEN %DO;
%PUT ERROR: Variable &CHARS. in list does not match type prescribed for this list.;
%END;
%ELSE %DO;

/* RUN PROC MEANS TO GET UNWEIGHTED MEANS */
PROC MEANS DATA=MYDATA NOPRINT;
BY &BYVAR.; 
VAR &ANALVARS.;
OUTPUT OUT=ALL_MEANS MEAN=&ANALVARS.;
RUN;
DATA ALL_MEANS(DROP=_TYPE_ _FREQ_);
SET ALL_MEANS;
RUN;

/* RUN PROC MEANS TO GET UNWEIGHTED SE*/
PROC MEANS DATA=MYDATA NOPRINT;
BY &BYVAR.; 
VAR &ANALVARS.;
OUTPUT OUT=ALL_SE STDERR=&ANALVARS.;
RUN;
DATA ALL_SE(DROP=_TYPE_ _FREQ_);
SET ALL_SE;
RUN;

* SPECIFY SORTING ORDER IF BY VARIABLES PRESENT;
%IF (%SUPERQ(BYVAR) NE ) %THEN %DO;
PROC SORT DATA=ALL_MEANS;
BY &BYVAR.;
RUN;
PROC SORT DATA=ALL_SE;
BY &BYVAR.;
RUN;
PROC SORT DATA=SS;
BY &BYVAR.;
RUN;
%END;

/* TRANSPOSE ALL THE VARIABLES */
PROC TRANSPOSE DATA=ALL_MEANS PREFIX=MEAN OUT=TMEANS;
BY &BYVAR.; 
RUN;
PROC SORT DATA=TMEANS;
BY  _NAME_ ;
RUN;

PROC TRANSPOSE DATA=ALL_SE PREFIX=SE OUT=TSE;
BY &BYVAR.; 
RUN;
PROC SORT DATA=TSE;
BY  _NAME_ ;
RUN;

/* CREATE DATASET WITH MEANS AND VARIANCES */
DATA A(RENAME=(MEAN1=MEAN SE1=SE _NAME_=VARIABLE));
MERGE TMEANS TSE;
BY _NAME_;
COUNT=1;
RUN;

PROC SORT DATA=A;
BY COUNT &BYVAR.;
RUN;

DATA A;
MERGE A SS;
BY COUNT &BYVAR.; 
RUN;

DATA A(KEEP=VARIABLE MEAN SE RSE VARIANCE ALPHA CI_HIGH CI_LOW &BYVAR. DFC);
SET A;
VARIANCE=SE*SE;
IF MEAN NE 0 THEN RSE= (SE/MEAN)*100;
ELSE RSE = .;
ALPHA = &ALPHA.;
DFC = SS - 1;
T = ABS(TINV(ALPHA,DFC));
CI_HIGH = MEAN+(SE*T);
CI_LOW = MEAN-(SE*T);
RUN;

%PRINT;
%END;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE VARTYPE ALL_MEANS ALL_SE TMEANS TSE;
QUIT;
%MEND;

/**********************************************************************/
/* CREATE DATASET WITH MEANS AND VARIANCES                            */
/* OF EACH GROUP OF 5 IMPUTED VARIABLES                               */
/**********************************************************************/
%MACRO IMPUTED_VARIABLES(USE_WEIGHTS);
DATA IMPUTED_VARS
	(KEEP=VARIABLE MEAN VARIANCE SE RSE &BYVAR. ALPHA DFC CI_LOW CI_HIGH);
RETAIN VARIABLE &BYVAR. MEAN SE VARIANCE RSE DFC ALPHA CI_LOW CI_HIGH; 
SET A;
RUN;

* SPECIFY SORTING ORDER IF BY VARIABLES PRESENT ;
%IF (%SUPERQ(BYVAR) NE ) %THEN %DO;
PROC SORT DATA=IMPUTED_VARS;
BY &BYVAR.;
RUN;
%END;

%LET VRS = ;
proc sql noprint;
 SELECT distinct variable INTO: VRS SEPARATED BY ' ' 
 FROM IMPUTED_VARS;
QUIT;
%LET VRS = %UPCASE(&VRS);

/*COUNT THE NUMBER OF IMPUTED VARIABLES*/
	%COUNT_VARS(&VRS.,DELIM=%STR( ));
	%LET AV = &N_VARS.;
%DO C=1 %TO &AV. %BY 5;
    %LET IMPVAR1 = %SCAN(&VRS., &C, ' ');
    %LET C2=%EVAL(&C + 1);
    %LET IMPVAR2 = %SCAN(&VRS., &C2., ' ');
    %LET C3=%EVAL(&C + 2);
    %LET IMPVAR3 = %SCAN(&VRS., &C3., ' ');
    %LET C4=%EVAL(&C + 3);
    %LET IMPVAR4 = %SCAN(&VRS., &C4., ' ');
    %LET C5=%EVAL(&C + 4);
    %LET IMPVAR5 = %SCAN(&VRS., &C5., ' ');

	%LET IMPVAR = "&IMPVAR1.", "&IMPVAR2.", "&IMPVAR3.", "&IMPVAR4.", "&IMPVAR5.";
	%LET IMPVAR1 = &IMPVAR1.-&IMPVAR5.;

/* KEEP DATA ONLY FOR THE 5 IMPUTED VARIABLES */
DATA IMPUTED_VARS1;
SET IMPUTED_VARS;
IF VARIABLE IN(&IMPVAR.);
RUN;

PROC TRANSPOSE DATA=IMPUTED_VARS1 OUT=TM PREFIX=MEAN;
VAR MEAN ;
BY &BYVAR.;
RUN;

PROC TRANSPOSE DATA=IMPUTED_VARS1 OUT=TV PREFIX=VAR;
VAR VARIANCE;
BY &BYVAR.;
RUN;

PROC TRANSPOSE DATA=IMPUTED_VARS1 OUT=TDF PREFIX=DFC;
VAR DFC;
BY &BYVAR.;
RUN;

DATA TALL(DROP=_NAME_ );
ATTRIB VARIABLE LENGTH=$25.;
MERGE TM TV TDF;
BY &BYVAR.;
Variable="&IMPVAR1.";
RUN;

PROC APPEND BASE=TOT_VAR DATA=TALL FORCE;
RUN;

%IF (%SUPERQ(BYVAR)NE ) %THEN %DO;
	%IF %UPCASE(&USE_WEIGHTS) = YES %THEN %DO;

%LET YBAR = YBAR1-YBAR45;

DATA AX(KEEP=&BYVAR. VARIABLE &YBAR.);
SET A;
IF VARIABLE IN(&IMPVAR.) THEN OUTPUT AX;
RUN;

PROC SORT DATA=AX;
BY VARIABLE;
RUN;

	PROC TRANSPOSE DATA=AX PREFIX=GP OUT=TYALLMI;
	BY VARIABLE;
	VAR &YBAR.;
	RUN;

DATA TYALLMI;
ATTRIB VARIABLE1 LENGTH=$25.;
SET TYALLMI;
IF VARIABLE IN(&IMPVAR.) THEN VARIABLE1 = "&IMPVAR1.";
RUN; 

PROC APPEND BASE=TYALLMIS DATA=TYALLMI FORCE;
RUN;

DATA TY4WM;
SET TYALLMIS;
RUN;
%END;
%END;
%END;

PROC DATASETS NOLIST LIBRARY=WORK;
DELETE TM TV TDF A AX TALL IMPUTED_VARS IMPUTED_VARS1 TYALLMI TYALLMIS;
QUIT;
%MEND;

/**********************************************************************/
/* CALCULATE THE TOTAL VARIANCE FOR ALL GROUPS OF 5 IMPUTED VARIABLES */
/**********************************************************************/
%MACRO TOT_VAR;
DATA TOT_VARS(DROP=MEAN1-MEAN5 VAR1-VAR5 SUMSQRD);
SET TOT_VAR;

* MEAN OF THE MEANS ;
MEAN_MEANS=MEAN(OF MEAN1-MEAN5);
SUMSQRD=0;
%DO I=1 %TO 5;
    SUMSQRD=SUM(SUMSQRD,((MEAN&I.-MEAN_MEANS)**2));
%END;
* VARIANCE OF THE MEANS ;
VAR_MEANS=SUMSQRD/4;

* MEAN OF THE VARIANCE ; 
MEAN_VARS=MEAN(OF VAR1-VAR5);

/* Total variance formula */
/* T = Mean of the variances + [(1+(1/5))*Variance of the means] */
TVAR = MEAN_VARS + (1.2*VAR_MEANS);
RUN;

PROC DATASETS NOLIST LIBRARY=WORK;
DELETE TOT_VAR;
QUIT;
%MEND;

%MACRO TOT_VARS;
	PROC SORT DATA=TOT_VARS;
	BY &BYVAR. VARIABLE;
	RUN;

/* RM = RELATIVE INCREASE OF VARIANCE DUE TO NONRESPONSE */
DATA TOT_VARS(DROP=DFC1-DFC5);
SET TOT_VARS;
* DEGREES OF FREEDOM ; 
  DFC = DFC1;
  ALPHA = &ALPHA.;  
  SE = SQRT(TVAR); 
  IF MEAN_MEANS NE 0 THEN RSE= (SE/MEAN_MEANS)*100;
  ELSE RSE = .;
/* DF from RUBINS book 1987, page 77 */
  RM = (1.2*VAR_MEANS)/MEAN_VARS;
  DFM = 4*(1+(1/RM))**2;
/* What definition to use? Rubin87(DFM) or Rubin99(DDF)*/
%IF &DF. = RUBIN87 %THEN DDF = DFM;
%ELSE %IF &DF. = RUBIN99 %THEN %DO;
/* DF from SUDAAN Language manual, page 89 Rubin definition 1999*/
/* DFC = DEGREES OF FREEDOM OF COMPLETE DATASET */
/* VDF [(DFC+1 / DFC+3)]*[(1- [(5+1)*VAR_MEANS]/5*TVAR)]*DFC */
/* DDF = 1/ [(1/DFC) + (1/VDF)]*/
  %IF &USE_WEIGHTS. = YES %THEN DFC = 44;;
  VDF = ((DFC+1)/(DFC+3))*(1-((6*VAR_MEANS)/(5*TVAR)))*DFC;
  DDF = 1/((1/DFM)+(1/VDF)); 
%END;;

	T = ABS(TINV(ALPHA,DDF));
	/* ROUND DF */
	DF = ROUND(DDF,1);
    CI_HIGH = MEAN_MEANS+(SE*T);
    CI_LOW = MEAN_MEANS-(SE*T);
RUN;

%IF %UPCASE(&USE_WEIGHTS) = YES %THEN 
	%LET TITLE6 = Total variance using the BRR method of variance estimation;
    %ELSE %IF %UPCASE(&USE_WEIGHTS) = NO %THEN 
    %LET TITLE6 = Total variance for unweighted data;

	PROC PRINT DATA=TOT_VARS SPLIT='*' UNIFORM;
	TITLE1 &TITLE1.;
	TITLE2 &TITLE2.;
	TITLE3 &TITLE3.;
	TITLE4 &TITLE4.;
	TITLE5 &TITLE5.;
	TITLE6 &TITLE6.;
	TITLE7 &TITLE7.;
	ID &BYVAR. VARIABLE;
	VAR MEAN_MEANS SE TVAR RSE;
	LABEL 
	    MEAN_MEANS   = "    Mean"
        SE           = "Standard*   Error*    (SE)"
	    RSE          = "Relative*Standard*   Error*((SE/Mean)x100)"
		TVAR 		 = "   Total*Variance"
		;
	RUN;

%IF %UPCASE(&DF) = RUBIN99 %THEN 
	%LET TITLE7 = Degrees of Freedom: Barnard & Rubin (1999) definition;
    %ELSE %IF %UPCASE(&DF) = RUBIN87 %THEN 
    %LET TITLE7 = Degrees of Freedom: Rubin (1987) definition;

	PROC PRINT DATA=TOT_VARS SPLIT='*' UNIFORM;
	TITLE1 &TITLE1.;
	TITLE2 &TITLE2.;
	TITLE3 &TITLE3.;
	TITLE4 &TITLE4.;
	TITLE5 &TITLE5.;
	TITLE6 "&CI.";
	TITLE7 &TITLE7.;
	TITLE8 &TITLE8.;
	ID &BYVAR. VARIABLE;
	VAR MEAN_MEANS DF CI_LOW CI_HIGH;
	LABEL 
		DF           = "Degrees of * Freedom"
	    MEAN_MEANS   = "    Mean"
		;
	RUN;

DATA IMPUTEDVARS;
RETAIN Variable &BYVAR. MEAN_MEANS SE TVAR RM RSE DFC ALPHA CI_LOW CI_HIGH; 
SET TOT_VARS;
RUN;

%IF (%SUPERQ(BYVAR)NE ) %THEN %DO;
	%IF %UPCASE(&USE_WEIGHTS) = NO %THEN %DO;
		DATA TY4UNWM(KEEP=VARIABLE &BYVAR. MEAN_MEANS TVAR DFC DFM DDF ALPHA);;
		SET IMPUTEDVARS;
		RUN;
	%END;
%END;
%MEND;

/*********************************************************************/
/* MACRO MEAN_VARIANCE                                               */
/*********************************************************************/
/****************************************************************/
/* DSN:  		 DATASET NAME									*/
/* FORMAT:       FORMATS IF ANY							        */
/* USE_WEIGHTS:  YES OR NO (DEFAULT = NO)				        */
/* BYVAR:  		 BY VARIABLES IF ANY							*/
/* ANALVARS: 	 ANALYSIS VARIABLE NAMES						*/
/* IMPUTED_VARS: IMPUTED VARIABLE NAMES							*/
/* CL:  		 CONFIDENCE LEVEL (DEFAULT IS 95)			    */
/* DF:  		 DEGREES OF FREEDOM DEFINITION                  */
/*								(DEFAULT IS RUBIN99)		    */
/*                              (OPTION IS RUBIN 87)            */
/* TITLE1:  	 TITLE 1 FOR OUTPUT							    */
/* TITLE2:  	 TITLE 2 FOR OUTPUT							    */
/* TITLE3:  	 TITLE 3 FOR OUTPUT							    */
/* XOUTPUT       PRINT EXTRA OUTPUT                             */
/****************************************************************/
/**********************************************************************/
/* CALCULATE MEAN, VARIANCE AND TOTAL VARIANCE                        */
/* FOR WEIGHTED OR UNWEIGHTED DATA									  */
/**********************************************************************/
%MACRO MEAN_VARIANCE(DSN = , 
  				  FORMAT = , 
			 USE_WEIGHTS = ,
				   BYVAR = , 
				ANALVARS = , 
			IMPUTED_VARS = ,
                      CL = ,
                      DF = , 
				  TITLE1 = ,
				  TITLE2 = ,
				  TITLE3 = ,
 				 XOUTPUT = );

/* DEFINE GLOBAL MACRO VARIABLES */
%GLOBAL ALPHA;
%GLOBAL UW;
%GLOBAL DFDEF;
%GLOBAL FRMT;
%GLOBAL BY_VAR;
%GLOBAL AVARS;
%GLOBAL MIVARS;

%LET DSN = %UPCASE(&DSN);
%LET USE_WEIGHTS = %UPCASE(&USE_WEIGHTS);
%LET BYVAR = %UPCASE(&BYVAR);
%LET ANALVARS = %UPCASE(&ANALVARS);
%LET IMPUTED_VARS = %UPCASE(&IMPUTED_VARS);
%LET XOUTPUT = %UPCASE(&XOUTPUT);
%LET TITLE4 = Consumer Expenditure Survey: Dataset &DSN.;
%LET TITLE5 = Collection year estimates;
%LET TITLE6 = ;
%LET TITLE7 = ;
%LET TITLE8 = ;
%LET TITLE9 = ;

%IF (%SUPERQ(USE_WEIGHTS) = ) %THEN %LET USE_WEIGHTS = NO;
%IF (%SUPERQ(XOUTPUT) = ) %THEN %LET XOUTPUT = NO;

%LET DF = %UPCASE(&DF);
%IF (%SUPERQ(DF) = ) %THEN %LET DF = RUBIN99;

%LET UW = &USE_WEIGHTS.;
%LET DFDEF = &DF.;
%LET FRMT = &FORMAT.;
%LET BY_VAR = %UPCASE(&BYVAR);
%IF (%SUPERQ(ANALVARS) = ) %THEN %LET AVARS = ;
%ELSE %LET AVARS = ANALVARS;
%IF (%SUPERQ(IMPUTED_VARS) = ) %THEN %LET MIVARS = ;
%ELSE %LET MIVARS = IMPUTED_VARS;

%PUT ;
%PUT Reading the dataset.;
	%READ_DATA;
	%PROC_FREQ;

%IF (%SUPERQ(CL) = ) %THEN %DO;
	%LET ALPHA = .025;
	%LET CI = 95% Confidence Intervals;
	%END;
%ELSE %DO;
	%LET ALPHA = (1-.&CL.)/2;
	%LET CI = &CL.% Confidence Intervals;
%END;

%IF (%SUPERQ(IMPUTED_VARS) = ) %THEN %DO;
	%IF %UPCASE(&USE_WEIGHTS) = YES %THEN %DO;
%PUT ;
%PUT Calculate weighted mean and variance for analysis variables;
%PUT &ANALVARS.;
		%WT_MEAN_VARIANCE(ANALVARS=&ANALVARS.);
	%END;
	%ELSE %IF %UPCASE(&USE_WEIGHTS) = NO %THEN %DO;
%PUT ;
%PUT Calculate unweighted mean and variance for analysis variables;
%PUT &ANALVARS.;
		%UNWT_MEAN_VARIANCE(ANALVARS=&ANALVARS.);
		%END;
%END;
%ELSE %DO;
%IF (%SUPERQ(ANALVARS) NE ) %THEN %DO;
/* CALCULATE MEANS AND VARIANCES FOR ANALYSIS VARIABLES */
	%IF %UPCASE(&USE_WEIGHTS) = YES %THEN %DO;
%PUT ;
%PUT Calculate weighted mean and variance for analysis variables;
%PUT &ANALVARS.;
		%WT_MEAN_VARIANCE(ANALVARS=&ANALVARS.);
	%END;
	%ELSE %IF %UPCASE(&USE_WEIGHTS) = NO %THEN %DO;
%PUT ;
%PUT Calculate unweighted mean and variance for analysis variables;
%PUT &ANALVARS.;
		%UNWT_MEAN_VARIANCE(ANALVARS=&ANALVARS.);
		%END;
%END;

/* CALCULATE MEANS AND VARIANCES FOR IMPUTED VARIABLES */
	%IF %UPCASE(&USE_WEIGHTS) = YES %THEN %DO;
%PUT ;
%PUT Calculate weighted mean and variance for multiply imputed variables;
%PUT &IMPUTED_VARS.;
		%WT_MEAN_VARIANCE(ANALVARS=&IMPUTED_VARS.);
		%END;
	%ELSE %IF %UPCASE(&USE_WEIGHTS) = NO %THEN %DO;
%PUT ;
%PUT Calculate unweighted mean and variance for multiply imputed variables;
%PUT &IMPUTED_VARS.;
		%UNWT_MEAN_VARIANCE(ANALVARS=&IMPUTED_VARS.);
		%END;

/*COUNT THE NUMBER OF IMPUTED VARIABLES*/
	%IMPUTED_VARIABLES(&USE_WEIGHTS.);

/* CALCULATE TOTAL VARIANCE FOR IMPUTED VARIABLES */
%PUT ;
%PUT Calculate total variance for multiply imputed data.;
%PUT ;
	%TOT_VAR;
	%TOT_VARS;
%END;

PROC DATASETS NOLIST LIBRARY=WORK;
DELETE TOT_VARS SS;
QUIT;

TITLE;
%MEND;

/* MACRO TO MAKE COMPARISONS BETWEEN BY GROUP LEVELS */
%MACRO COMPARE(GP1, GP2);
%LET GPNAME = GP&GP1._vs_GP&GP2.;
%LET GPDIFF = GP&GP1. -  GP&GP2.;

/* BY GROUP COMPARISONS OF NONIMPUTED VARIABLES */
%IF &DSNGPS. = ANALVARS %THEN %DO;
%IF &UW. = YES %THEN %DO;
/* GET THE DIFFERENCE OF THE MEANS */
DATA TY1(KEEP=_NAME_ &GPNAME.);
SET TYAV;
&GPNAME. = &GPDIFF.;
RUN;

PROC SORT DATA = TY1;
BY _NAME_;
RUN;

/* TRANSPOSE THE VARIABLE GP&GP1._vs_GP&GP2. */
PROC TRANSPOSE DATA=TY1 PREFIX=diff OUT=TYS;
by _name_;
var &GPNAME.;
RUN;

DATA TYS;
ATTRIB _NAME_ LENGTH=$40;
ATTRIB Compare_Means LENGTH=$20;
SET TYS;
Compare_Means="&GPNAME.";
RUN;

PROC APPEND BASE=TY2 DATA=TYS FORCE;
RUN;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE TYS TY1;
QUIT;
%END;

%ELSE %IF &UW. = NO %THEN %DO; 
%IF &BYV. = 1 %THEN %DO; 
DATA MYTTEST;
SET MYDATA;
ALPHA2=2*&ALPHA.;
IF GROUP = &GP1. THEN &BYVAR._ = &GP1.;
ELSE IF GROUP = &GP2. THEN &BYVAR._ = &GP2.;
RUN;
%END;
%ELSE %DO;
DATA MYTTEST;
set MYDATA;
ALPHA2=2*&ALPHA.;
IF GROUP = &GP1. THEN Groups = &GP1.;
ELSE IF GROUP = &GP2. THEN Groups = &GP2.;
RUN;
%END;

%LET TTESTVARS = ;

PROC SQL NOPRINT;
 SELECT _NAME_ INTO: TTESTVARS SEPARATED BY ' '
 FROM TYAV;
QUIT;

%LET ALPHA2 = ;

PROC SQL NOPRINT;
 SELECT DISTINCT ALPHA2 INTO: ALPHA2
 FROM MYTTEST;
QUIT;

%IF &BYV. = 1 %THEN %DO; 
/* RUN PROC TTEST TO GET STATS FOR DIFFERENCE OF THE MEANS */
PROC TTEST DATA= MYTTEST ALPHA=&ALPHA2.;
	TITLE1 &TITLE1.;
	TITLE2 &TITLE2.;
	TITLE3 &TITLE3.;
	TITLE4 "Consumer Expenditure Survey";
	TITLE5 "Compare MEANS between GROUPS of variable &BYVAR.";
    TITLE6 "For unweighted data";
    TITLE7 "ALPHA =&ALPHA2.";
  CLASS &BYVAR._;
  VAR &TTESTVARS.;
RUN;
%END;
%ELSE %DO;
/* RUN PROC TTEST TO GET STATS FOR DIFFERENCE OF THE MEANS */
PROC TTEST DATA= MYTTEST ALPHA=&ALPHA2.;
	TITLE1 &TITLE1.;
	TITLE2 &TITLE2.;
	TITLE3 &TITLE3.;
	TITLE4 "Consumer Expenditure Survey";
	TITLE5 "Compare MEANS between GROUPS of variable &BYVAR.";
    TITLE6 "For unweighted data";
    TITLE7 "ALPHA =&ALPHA2.";
  CLASS GROUPS;
  VAR &TTESTVARS.;
RUN;
%END;
%END;
%END;

/* BY GROUP COMPARISONS OF IMPUTED VARIABLES */
%IF &DSNGPS. = IMPUTED_VARS %THEN %DO;
%IF &UW. = YES %THEN %DO;
/* GET THE DIFFERENCE OF THE MEANS */
DATA TY1(KEEP=VARIABLE VARIABLE1 _NAME_ &GPNAME.);
SET TY4WM;
&GPNAME. = &GPDIFF.;
RUN;

PROC SORT DATA=TY1;
BY VARIABLE1 VARIABLE;
RUN;

PROC TRANSPOSE DATA=TY1 prefix=diff OUT=TYS;
BY VARIABLE1 VARIABLE;
var &GPNAME.;
RUN;

data TYS;
set TYS;
  ARRAY diff(44) diff1-diff44;
  ARRAY SQDIFF(44) SQDIFF1-SQDIFF44;
    DO I = 1 TO 44;
      SQDIFF(I) = (diff(I) - diff45)**2;
      DROP I; 
    END; 
  MEAN = diff45;
  VARIANCE = SUM(OF SQDIFF(*))/44;
  SE = SQRT(VARIANCE); /* HORIZONTAL SUM */
  DFC = 44;
run;

DATA TYS
	(KEEP=variable1 VARIABLE _name_ MEAN VARIANCE SE DFC);
RETAIN variable1 VARIABLE _name_ MEAN SE VARIANCE DFC; 
SET TYS;
RUN;

PROC TRANSPOSE DATA=TYS OUT=TM PREFIX=MEAN;
VAR MEAN;
by variable1;
RUN;

PROC TRANSPOSE DATA=TYS OUT=TV PREFIX=VAR;
VAR VARIANCE;
by variable1;
RUN;

DATA TALL(DROP=_NAME_  VARIABLE1);
ATTRIB Compare_Means LENGTH=$25.;
MERGE TM TV;
Compare_Means="&GPNAME.";
Variable=VARIABLE1;
RUN;

PROC APPEND BASE=TY2 DATA=TALL FORCE;
RUN;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE TY1 TYS TM TV TALL;
QUIT;
%END;

%ELSE %IF &UW. = NO %THEN %DO;
/* GET T_STATS FOR THE DIFFERENCE OF THE MEANS */
DATA TY1;
SET TY4UNWM;
RUN;

PROC SORT DATA=TY1;
BY VARIABLE &BYVAR.;
RUN;

PROC TRANSPOSE DATA=TY1 PREFIX=VAR OUT=ZSCY;
BY VARIABLE;
VAR TVAR;
RUN;

PROC TRANSPOSE DATA=TY1 PREFIX=MEAN OUT=ZSCZ;
BY VARIABLE;
VAR MEAN_MEANS;
RUN;

%IF &DFDEF. = RUBIN87 %THEN  %DO;
PROC TRANSPOSE DATA=TY1 PREFIX=DF OUT=ZSCDF;
BY VARIABLE;
VAR  DFM;
RUN;
%END;
%ELSE %IF &DFDEF. = RUBIN99 %THEN  %DO;
PROC TRANSPOSE DATA=TY1 PREFIX=DF OUT=ZSCDF;
BY VARIABLE;
VAR  DDF;
RUN;
%END;
/* CALCULATE THE T_STAT VALUES */
DATA ZSALL(keep=VARIABLE COMPARE_MEANS DIFF_MEANS VAR_MEANS DF_DIFF_MEANS);
MERGE ZSCY ZSCZ ZSCDF;
BY VARIABLE;
ATTRIB Compare_Means LENGTH=$20;
Compare_Means="GP&GP1._vs_GP&GP2.";
Diff_Means = MEAN&GP1. - MEAN&GP2.;
Var_Means = VAR&GP1. + VAR&GP2.;
DF_Diff_Means = DF&GP1. + DF&GP2.;
RUN;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE TY1 ZSCY ZSCZ ZSCDF;
QUIT;

PROC APPEND BASE=TY2 DATA=ZSALL FORCE;
RUN;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE ZSALL;
QUIT;
%END;
%END;
%MEND;

%MACRO TEST(BYVAR);
%LET TITLE4 = Consumer Expenditure Survey;
%LET TITLE5 = Compare MEANS between GROUPS of variable &BYVAR.;

/* BY GROUP COMPARISONS OF NONIMPUTED VARIABLES */
%IF &DSNGPS. = ANALVARS %THEN %DO;
%IF &UW. = YES %THEN %DO;
%LET TITLE6 = Using the BRR method of variance estimation;
/* CALCULATE SE, T VALUE, F VALUE, AND P VALUE FOR THE F_TEST */
DATA COMPARE_&DSNGPS.;
  SET TY2;
  Variable = _NAME_;
  ARRAY diffs(44) diff1-diff44;
  ARRAY SQDIFF(44) SQDIFF1-SQDIFF44;
    DO I = 1 TO 44;
      SQDIFF(I) = (diffs(I) - diff45)**2;
      DROP I; 
    END; 
  Diff_Means = diff45;
  SE_Diff_Means = SQRT( SUM(OF SQDIFF(*))/44 ); /* HORIZONTAL SUM */
  IF SE_Diff_Means NE 0 THEN TValue = Diff_Means/SE_Diff_Means;
  ELSE TValue = .;
  F_Test=TVALUE*TVALUE;
  P_Value=1-PROBF(F_TEST,1,44);
  DF_Diff_Means = 44;
RUN;

PROC SORT DATA=COMPARE_&DSNGPS.;
BY _NAME_;
RUN;

DATA COMPARE_&DSNGPS.(KEEP=VARIABLE COMPARE_MEANS DIFF_MEANS SE_DIFF_MEANS DF_DIFF_MEANS TVALUE P_VALUE);
SET COMPARE_&DSNGPS.;
RUN;

PROC SORT DATA=COMPARE_&DSNGPS.;
BY VARIABLE COMPARE_MEANS;
RUN;

/* PRINT FINAL OUTPUT DATASET */
PROC PRINT DATA=COMPARE_&DSNGPS.;
	TITLE1 &TITLE1.;
	TITLE2 &TITLE2.;
	TITLE3 &TITLE3.;
	TITLE4 &TITLE4.;
	TITLE5 &TITLE5.;
	TITLE6 &TITLE6.;
ID VARIABLE ;
VAR COMPARE_MEANS DIFF_MEANS SE_DIFF_MEANS DF_DIFF_MEANS TVALUE P_VALUE;
RUN;

/* DELETE APPEND DATASETS */
PROC DATASETS LIBRARY=WORK NOLIST;
DELETE TY2;
QUIT;
%END;
%END;

/* BY GROUP COMPARISONS OF IMPUTED VARIABLES */
%IF &DSNGPS. = IMPUTED_VARS %THEN %DO;
%IF &UW. = YES %THEN %DO;
%LET TITLE6 = Using the BRR method of variance estimation;
DATA COMPARE_&DSNGPS.(DROP=MEAN1-MEAN5 VAR1-VAR5 SUMSQRD);
SET TY2;
* DEGREES OF FREEDOM ; 
DFC = 44;
* MEAN OF THE DIFFERENCE OF THE MEANS ;
Mean_Means=MEAN(OF MEAN1-MEAN5);
* MEAN OF THE VARIANCE ; 
Mean_Vars=MEAN(OF VAR1-VAR5);
SUMSQRD=0;
%DO I=1 %TO 5;
    SUMSQRD=SUM(SUMSQRD,((MEAN&I.-MEAN_MEANS)**2));
%END;
* VARIANCE OF THE MEANS ;
Var_Means=SUMSQRD/4;
/* Total variance formula */
/* T = Mean of the variances + [(1+(1/5))*Variance of the means] */
TVAR = MEAN_VARS + (1.2*VAR_MEANS);
SE_Diff_Means = SQRT(TVAR);

ALPHA = &ALPHA.;  

IF SE_Diff_Means NE 0 THEN TValue = Mean_Means/SE_Diff_Means;
ELSE TValue = .;

F_Test = TVALUE*TVALUE;

/* MEAN_MEANS IS THE DIFFERENCE OF THE MEANS OF THE IMPUTED VARIABLES */
Diff_Means = MEAN_MEANS;

/* DF from RUBINS book 1987, page 77*/
RM = (1.2*VAR_MEANS)/MEAN_VARS;
DFM = 4*(1+(1/RM))**2;

/* What definition to use? Rubin87(DFM) or Rubin99(DDF)*/
%IF &DFDEF. = RUBIN87 %THEN DDF = DFM;
%ELSE %IF &DFDEF. = RUBIN99 %THEN %DO;
/* DF from SUDAAN Language manual, page 89 Rubin definition 1999*/
/* DFC = DEGREES OF FREEDOM OF COMPLETE DATASET */
/* VDF [(DFC+1 / DFC+3)]*[(1- [(5+1)*VAR_MEANS]/5*TVAR)]*DFC */
/* DDF = 1/ [(1/DFC) + (1/VDF)]*/
  VDF = ((DFC+1)/(DFC+3))*(1-((6*VAR_MEANS)/(5*TVAR)))*DFC;
  DDF = 1/((1/DFM)+(1/VDF)); 
  %END;;

    P_Value=1-PROBF(F_TEST,1,DDF);
	/* ROUND DF */
	DF_Diff_Means = ROUND(DDF,1);
RUN;
%END;

%ELSE %DO;
%LET TITLE6 = For unweighted data;
DATA COMPARE_&DSNGPS.;
SET TY2;
SE_Diff_Means = SQRT(VAR_MEANS);
  ALPHA = &ALPHA.;  

/* MEAN_MEANS IS THE DIFFERENCE OF THE MEANS OF THE IMPUTED VARIABLES */
  IF SE_Diff_Means NE 0 THEN TValue = Diff_Means/SE_Diff_Means;
  ELSE TValue = .;

  F_Test = TVALUE*TVALUE;

	DDF = DF_Diff_Means;
    P_Value=1-PROBF(F_TEST,1,DDF);
	/* ROUND DF */
	DF_Diff_Means = ROUND(DDF,1);
RUN;
%END;

PROC SORT DATA=COMPARE_&DSNGPS.;
BY VARIABLE COMPARE_MEANS;
RUN;

%IF &DFDEF. = RUBIN99 %THEN 
	%LET TITLE7 = Degrees of Freedom: Barnard & Rubin (1999) definition;
    %ELSE %IF &DFDEF. = RUBIN87 %THEN 
    %LET TITLE7 = Degrees of Freedom: Rubin (1987) definition;

/* PRINT FINAL OUTPUT DATASET */
PROC PRINT DATA=COMPARE_&DSNGPS.;
	TITLE1 &TITLE1.;
	TITLE2 &TITLE2.;
	TITLE3 &TITLE3.;
	TITLE4 &TITLE4.;
	TITLE5 "Compare MEANS of Imputed data between GROUPS of variable &BYVAR.";
	TITLE6 &TITLE6.;
	TITLE7 &TITLE7.;
ID VARIABLE ;
VAR COMPARE_MEANS DIFF_MEANS SE_DIFF_MEANS DF_DIFF_MEANS TVALUE P_VALUE;
RUN;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE ZSCS;
QUIT;
%END;

/* DELETE APPEND DATASETS */
PROC DATASETS LIBRARY=WORK NOLIST;
DELETE TY2;
QUIT;
%MEND;

/*********************************************************************/
/* MACRO COMPARE_GROUPS                                              */
/*********************************************************************/
/****************************************************************/
/* GPS:          GROUPS TO BE COMPARE					        */
/* TITLE1:  	 TITLE 1 FOR OUTPUT							    */
/* TITLE2:  	 TITLE 2 FOR OUTPUT							    */
/* TITLE3:  	 TITLE 3 FOR OUTPUT							    */
/****************************************************************/
/****************************************************************/
/* COMPARE MEANS OF GROUPS OF BY VARIABLE                       */
/* FOR WEIGHTED OR UNWEIGHTED DATA							    */
/****************************************************************/

%MACRO COMPARE_GROUPS(GPS = ,
			       TITLE1 = ,
			       TITLE2 = ,
			       TITLE3 = );

OPTIONS PAGENO=1 NOCENTER;
 
%LET TITLE1 = ;
%LET TITLE2 = ;
%LET TITLE3 = ;
%LET GPS = %UPCASE(&GPS);
%LET FROM = &AVARS. &MIVARS.;
%LET BYVAR = &BY_VAR.;

%COUNT_VARS(&FROM.,DELIM=%STR( ));
	%LET F_GPS = &N_VARS.;
		%DO FG=1 %TO &F_GPS.;
		    %LET DSNGPS = %SCAN(&FROM., &FG, ' ');

%PUT ;
%IF &DSNGPS. = ANALVARS %THEN 
%PUT Compare groups of ANALVARS; 
%ELSE %PUT Compare groups of IMPUTED_VARS.;;

%COUNT_VARS(&GPS.,DELIM=%STR( ));
	%LET C_GPS = &N_VARS.;
		%DO CG=1 %TO &C_GPS. %BY 2;
			%LET GP1 = %SCAN(&GPS., &CG, ' ');
			%LET CG2 = %EVAL(&CG + 1);
			%LET GP2 = %SCAN(&GPS., &CG2, ' ');
		%PUT ;
		%PUT Compare &GP1. and &GP2..;
			%COMPARE(&GP1., &GP2.);
		%END;
	%TEST(&BYVAR.);
%END;

TITLE;
%MEND;


/**********************************************************************/
/* THE MACRO WT_PROC_REG PERFORM OLS REGRESSIONS                      */
/* PERFORM WEIGHTED REGRESSIONS USING BRR                             */
/**********************************************************************/
%MACRO WT_PROC_REG;
%GLOBAL DVAR;
%LET DVAR=%SCAN(&DVARS, &N );

* SPECIFY SORTING ORDER IF BY VARIABLES PRESENT;
%IF (%SUPERQ(BYVAR) NE ) %THEN %DO;
PROC SORT DATA=MYDATA;
BY &BYVAR.;
RUN;
%END;

/* RUN REGRESSION ON FINLWT21 TO GET SOME GENERAL STATISTICS */
ODS LISTING CLOSE;
ODS OUTPUT ANOVA=AT (KEEP = &BYVAR. DF SOURCE)
			FITSTATISTICS=FS (KEEP=&BYVAR. LABEL1 CVALUE1 LABEL2 CVALUE2)
			; 
PROC REG  DATA=MYDATA;
BY &BYVAR.;
 WEIGHT FINLWT21;
 MODEL &DVAR. = &IVARS.;
 TITLE ;
RUN;
ODS LISTING;

%LOCAL DSID RC VARNUM;
%GLOBAL RS DM SS;

/* GET THE R_SQUARE AND THE DEPENDENT MEAN */
/* FORM THE FIT STATISTICS DATASET */
/* VALUE IS A CHARACTER VARIABLE */
DATA FS(KEEP=&BYVAR. VALUE LABEL);
ATTRIB VALUE LENGTH=$16.4;
SET FS;
IF LABEL1="Coeff Var" THEN DELETE;
IF LABEL1="Dependent Mean" THEN 
	DO;
		VALUE=CVALUE1;
		LABEL="DM";
	END;
IF LABEL2="R-Square" THEN 
	DO;
		VALUE=CVALUE2;
		LABEL="RS";
	END;
RUN;

%LET DSID=%SYSFUNC(OPEN(FS,IS));

%DO OBS=1 %TO 2;
%LET VARNUM=%SYSFUNC(VARNUM(&DSID,LABEL));
%LET RC=%SYSFUNC(FETCHOBS(&DSID,&OBS));
%LET LBL=%SYSFUNC(GETVARC(&DSID,&VARNUM));

%LET VARNUM=%SYSFUNC(VARNUM(&DSID,VALUE));
%LET RC=%SYSFUNC(FETCHOBS(&DSID,&OBS));

%IF &LBL=RS %THEN %LET RS=%SYSFUNC(GETVARC(&DSID, &VARNUM));
%IF &LBL=DM %THEN %LET DM=%SYSFUNC(GETVARC(&DSID, &VARNUM));
%END;

%LET RC=%SYSFUNC(CLOSE(&DSID));

/* GET THE SAMPLE SIZE FROM THE ANOVA TABLE DATASET */
/* VALUE IS A NUMERIC VARIABLE */
DATA AT(KEEP=&BYVAR. VALUE LABEL);
SET AT;
IF SOURCE="Error" OR SOURCE="Model" THEN DELETE;
IF SOURCE="Corrected Total" THEN 
	DO;
		LABEL="SS";
		VALUE=DF + 1;
	END;
RUN;

%LET DSID=%SYSFUNC(OPEN(AT,IS));
%LET OBS=1;
%LET VARNUM=%SYSFUNC(VARNUM(&DSID,LABEL));
%LET RC=%SYSFUNC(FETCHOBS(&DSID,&OBS));
%LET LBL=%SYSFUNC(GETVARC(&DSID,&VARNUM));

%LET VARNUM=%SYSFUNC(VARNUM(&DSID,VALUE));
%LET RC=%SYSFUNC(FETCHOBS(&DSID,&OBS));
%IF &LBL=SS %THEN %LET SS=%SYSFUNC(GETVARN(&DSID, &VARNUM));

%LET RC=%SYSFUNC(CLOSE(&DSID));

* GET SOME STATISTICS IF BY VARIABLES PRESENT;
%IF (%SUPERQ(BYVAR) NE ) %THEN %DO;
PROC TRANSPOSE DATA=fs OUT=fs;
id label;
BY &BYVAR.;
  VAR value ;
RUN;

data at(rename=(value=SS));
set at(keep=&BYVAR. value);
run;

data stats;
merge at fs(drop=_NAME_);
BY &BYVAR.;
run;
%END;

ODS LISTING CLOSE;
/* RUN THE REGRESSION 45 TIMES */
%DO I = 1 %TO 45;
/* KEEP THE INTERCEPT AND ALL THE VARIABLES IN YOUR MODEL STATEMENT */
PROC REG  DATA=MYDATA NOPRINT OUTEST=REG&I(KEEP=&BYVAR. INTERCEPT &IVARS.);
BY &BYVAR.;
WEIGHT WTREP&I;
 MODEL &DVAR. = &IVARS.;
RUN;

PROC APPEND BASE=PARAMS1 DATA=REG&I FORCE;
RUN;
%END;
ODS LISTING;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE REG1-REG45 AT FS ;
QUIT;

DATA PARAMS;
SET PARAMS1;
RUN;

* SPECIFY SORTING ORDER IF BY VARIABLES PRESENT;
%IF (%SUPERQ(BYVAR) NE ) %THEN %DO;
PROC SORT DATA=PARAMS;
BY &BYVAR.;
RUN;
%END;

DATA PARAMS_&DVAR.;
SET PARAMS;
RUN;

/* TRANSPOSE THE INTERCEPT, AND ALL THE VARIABLES IN YOUR MODEL STATEMENT */
PROC TRANSPOSE DATA=PARAMS PREFIX=COEFF OUT=TPARAMS;
BY &BYVAR.;
  VAR INTERCEPT &IVARS.;
RUN;

/* CALCULATE SE, T VALUE, AND P VALUE FOR THE T_TEST */
DATA A(KEEP=&BYVAR. PARAMETER COEFF SE TVALUE PVALUE DFC);
  SET TPARAMS;
  PARAMETER = _NAME_;
  ARRAY PARMS(44) COEFF1-COEFF44;
  ARRAY SQDIFF(44) SQDIFF1-SQDIFF44;
    DO I = 1 TO 44;
      SQDIFF(I) = (PARMS(I) - COEFF45)**2;
    END; 
  COEFF = COEFF45;
  DFC=44;
  SE = SQRT( SUM(OF SQDIFF(*))/44 ); /* HORIZONTAL SUM */
  IF SE GT 0 THEN TVALUE = COEFF/SE;
  ELSE TVALUE = 0;
  PVALUE=(1-PROBT(ABS(TVALUE),44))*2; /* DF=44*/
RUN;

%IF (%SUPERQ(XOUTPUT) = YES) OR (%SUPERQ(IMPUTED_VARS) = ) %THEN %DO;
%IF (%SUPERQ(BYVAR) NE ) %THEN %DO;
%IF (%SUPERQ(XOUTPUT) = YES) %THEN 
	%LET TITLE9 = "            Independent variables: %EVAL(&IVS. - 1)";
	%ELSE %LET TITLE9 = "            Independent variables: &IV.";;
PROC PRINT DATA=STATS SPLIT='*' UNIFORM;
  TITLE1 &TITLE1.;
  TITLE2 &TITLE2.;
  TITLE3 &TITLE3.;
  TITLE4 "The REG Procedure using replicate weights" ;
  TITLE5 "Balanced Repeated Replication (BRR) method" ;
  TITLE6 "Regression on Dataset &DSN. for Dependent Variable: &DVAR.";
  TITLE7 ;
  TITLE8 "   Denominator degrees of freedom: 44";
  TITLE9 &TITLE9.;
ID &BYVAR.;
LABEL 
	SS = "   Sample*     size"
	RS = " R-Square"
	DM = "Dependent*     mean"
    ;
run;

PROC PRINT DATA=A SPLIT='*' UNIFORM;
BY &BYVAR.;
  TITLE1 &TITLE1.;
  TITLE2 &TITLE2.;
  TITLE3 &TITLE3.;
  TITLE4 "The REG Procedure using replicate weights" ;
  TITLE5 "Balanced Repeated Replication (BRR) method" ;
  TITLE6 "Regression on Dataset &DSN. for Dependent Variable: &DVAR.";
  TITLE7 ;
  TITLE8 "                           Parameter Estimates";

VAR COEFF SE TVALUE PVALUE;
ID PARAMETER;
LABEL 
	Parameter = "Variable   "
	Coeff     = "Parameter *Estimate "
	SE        = "Standard  * Error  "
	tvalue    = "t Value"
	pvalue    = "Pr > |t|"
    ;
RUN;
%END;
%ELSE %DO;
%IF (%SUPERQ(XOUTPUT) = YES) %THEN 
	%LET TITLE8 = "            Independent variables: %EVAL(&IVS. - 1)";
	%ELSE %LET TITLE8 = "            Independent variables: &IV.";;
PROC PRINT DATA=A SPLIT='*' UNIFORM;
  TITLE1 &TITLE1.;
  TITLE2 &TITLE2.;
  TITLE3 &TITLE3.;
  TITLE4 "The REG Procedure using replicate weights, BRR method";
  TITLE5 "Regression on Dataset &DSN. for Dependent Variable: &DVAR.";
  TITLE6 "                         R-Square: &RS.        Dependent mean: &DM.";
  TITLE7 "   Denominator degrees of freedom: 44               Sample size: &SS." ;
  TITLE8 &TITLE8.;
  TITLE9 "                           Parameter Estimates";

VAR COEFF SE TVALUE PVALUE;
ID PARAMETER;
LABEL 
	Parameter = "Variable   "
	Coeff     = "Parameter *Estimate "
	SE        = "Standard  * Error  "
	tvalue    = "t Value"
	pvalue    = "Pr > |t|"
    ;
RUN;
%END;
%END;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE TPARAMS PARAMS1 PARAMS;
QUIT;
%MEND;

/***************************************************************************/
/* THE MACRO UNWT_PROC_REG PERFORM OLS REGRESSIONS FOR UNWEIGHTED DATA     */
/***************************************************************************/
%MACRO UNWT_PROC_REG;
%GLOBAL DVAR;
%LET DVAR=%SCAN(&DVARS, &N );

* SPECIFY SORTING ORDER IF BY VARIABLES PRESENT;
%IF (%SUPERQ(BYVAR) NE ) %THEN %DO;
PROC SORT DATA=MYDATA;
BY &BYVAR.;
RUN;
%END;

%IF (%SUPERQ(XOUTPUT) = YES) OR (%SUPERQ(IMPUTED_VARS) = ) %THEN %DO;
PROC REG  DATA=MYDATA;
BY &BYVAR.;
TITLE1 &TITLE1.;
TITLE2 &TITLE2.;
TITLE3 &TITLE3.;
TITLE4 "Consumer Expenditure Survey";
TITLE5 "Regression on Dataset &DSN. for Dependent Variable: &DVAR.";
TITLE6 "Unweighted data";
 MODEL &DVAR. = &IVARS.;
QUIT;
%END;

/* KEEP THE INTERCEPT AND ALL THE VARIABLES IN YOUR MODEL STATEMENT */
ODS LISTING CLOSE;
ODS OUTPUT PARAMETERESTIMATES=PE(KEEP=&BYVAR. VARIABLE ESTIMATE STDERR )
	       ANOVA = SS(KEEP = &BYVAR. SOURCE DF)
			;
PROC REG DATA=MYDATA;
 BY &BYVAR.;
 MODEL &DVAR. = &IVARS.;
QUIT;
ODS LISTING;

DATA SS(KEEP=&BYVAR. SS COUNT);
SET SS;
COUNT=1;
SS=DF+1;
IF SOURCE = 'Corrected Total' THEN OUTPUT SS;
RUN;

DATA A(KEEP=&BYVAR. PARAMETER COEFF SE COUNT);
SET PE;
COEFF=ESTIMATE;
PARAMETER=VARIABLE;
SE=STDERR;
COUNT=1;
RUN;

PROC SORT DATA=A;
BY COUNT &BYVAR.;
RUN;

PROC SORT DATA=SS;
BY COUNT &BYVAR.;
RUN;

DATA A;
MERGE A SS;
BY COUNT &BYVAR.; 
RUN;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE PE SS;
QUIT;
%MEND;

/**********************************************************************/
/* THE MACRO LOGISTIC_OPTIONS GET OPTIONS FOR THE LOGISTIC MACROS     */
/**********************************************************************/
%MACRO LOGISTIC_OPTIONS;
OPTIONS NOSERROR;
%GLOBAL DVAR;
%LET DVAR=%SCAN(&DVARS, &N );

* SPECIFY SORTING ORDER IF BY VARIABLES PRESENT;
%IF (%SUPERQ(BYVAR) NE ) %THEN %DO;
PROC SORT DATA=MYDATA;
BY &BYVAR.;
RUN;
%END;

* GET THE LEVELS OF THE DEPENDENT VARIABLE;
PROC FREQ DATA=MYDATA NOPRINT;
TABLES &DVAR. /OUT=LEVELS ;
RUN;

%LOCAL DSID RC;
%GLOBAL LEVELS;
%LET DSID=%SYSFUNC(OPEN(LEVELS));
%LET LEVELS =%SYSFUNC(ATTRN(&DSID,NOBS));
%LET RC=%SYSFUNC(CLOSE(&DSID));

%PUT Response variable &DVAR. has &LEVELS. levels.;
%PUT ;

* SPECIFY THE SORTING ORDER FOR THE LEVELS OF THE RESPONSE VARIABLE ;
%GLOBAL OPTIONS;
%IF (%SUPERQ(SORT_ORDER) = ) %THEN %DO;
		%IF &LEVELS. = 2 %THEN %LET OPTIONS = DESCENDING;
		%ELSE %IF &LEVELS. GT 2 %THEN %LET OPTIONS = ORDER=INTERNAL;
		%PUT The macro will assign the default sorting order to the;
    	%PUT Response variable &DVAR.: SORT_ORDER is &OPTIONS.. ;
		%PUT ;
	%END;
%ELSE %DO;
		%LET OPTIONS = ORDER=&SORT_ORDER; 
		%PUT SORT_ORDER for the Response variable &DVAR. is &OPTIONS.. ;
		%PUT ;
      %END;

* FOR TWO LEVEL DEPENDENT VARIABLE (0,1);
* PROC LOGISTIC is modeling the probability that DEPENDENT VARIABLE='1';

* FOR MORE THAN TWO LEVELS DEPENDENT VARIABLE;
* THE OPTIONS FOR ORDER ARE INTERNAL, FORMATTED, DATA, FREQ ;

* DATA = ORDER OF APPEARANCE IN THE INPUT DATA SET;
* FREQ = DESCENDING FREQUENCY COUNT, LEVELS WITH THE 
	MOST OBSERVATIONS COME FIRST IN THE ORDER;
* INTERNAL = UNFORMATTED VALUE;
* FORMATTED = EXTERNAL FORMATTED VALUE, EXCEPT FOR 
	NUMERIC VARIABLES WITH NO EXPLICIT FORMAT, WHICH
	ARE SORTED BY THE UNFORMATTED (INTERNAL) VALUE;

* READ THE INDEPENDENT CLASSIFICATION VARIABLES AND SORTING OPTIONS;
* IF ANY, FOR THE CLASS STATEMENT IN THE LOGISTIC PROCEDURE;
%GLOBAL CLASS;
%IF (%SUPERQ(CLASSVARS) = ) %THEN %LET CLASS= ;
	%ELSE %LET CLASS=&CLASSVARS; 
%MEND;

/**********************************************************************/
/* THE MACRO WT_PROC_LOGISTIC PERFORM LOGISTIC REGRESSIONS            */
/* default for SAS technique=Fisher                                   */
/**********************************************************************/
%MACRO WT_PROC_LOGISTIC;
/* RUN MACRO LOGISTIC_OPTIONS */
%LOGISTIC_OPTIONS;

/* RUN REGRESSION ON FINLWT21 TO GET SOME GENERAL STATISTICS */
%IF (%SUPERQ(XOUTPUT) = YES) OR (%SUPERQ(IMPUTED_VARS) = ) %THEN %DO;
%IF (%SUPERQ(XOUTPUT) = YES) %THEN 
	%LET TITLE9 = "         Independent variables: %EVAL(&IVS. - 1)";
	%ELSE %LET TITLE9 = "         Independent variables: &IV.";;
ODS SELECT MODELINFO RESPONSEPROFILE CONVERGENCESTATUS;
PROC LOGISTIC DATA=MYDATA &OPTIONS.;
BY &BYVAR.;
 WEIGHT FINLWT21;
 CLASS &CLASS.;
 MODEL &DVAR. = &IVARS./technique=Fisher;
  TITLE1 &TITLE1.;
  TITLE2 &TITLE2.;
  TITLE3 &TITLE3.;
  TITLE4 "The LOGISTIC Procedure using replicate weights" ;
  TITLE5 "Balanced Repeated Replication (BRR) method" ;
  TITLE6 "Dataset &DSN. = WORK.MYDATA";
  TITLE7 ;
  TITLE8 "Denominator degrees of freedom: 44";
  TITLE9 &TITLE9.;
RUN;
%END;

ODS LISTING CLOSE;
/* RUN THE REGRESSION 45 TIMES */
%DO I = 1 %TO 45;
/* KEEP THE INTERCEPT AND ALL THE VARIABLES IN YOUR MODEL STATEMENT */
PROC LOGISTIC DATA=MYDATA NOPRINT &OPTIONS. OUTEST=REG&I;
BY &BYVAR.;
 WEIGHT WTREP&I;
 CLASS &CLASS.;
 MODEL &DVAR. = &IVARS./technique=Fisher;
RUN;

PROC APPEND BASE=PARAMS1 DATA=REG&I FORCE;
RUN;
%END;
ODS LISTING;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE REG1-REG45 LEVELS;
QUIT;

DATA PARAMS(DROP=_LNLIKE_);
SET PARAMS1;
RUN;

* SPECIFY SORTING ORDER IF BY VARIABLES PRESENT;
%IF (%SUPERQ(BYVAR) NE ) %THEN %DO;
PROC SORT DATA=PARAMS;
BY &BYVAR.;
RUN;
%END;

DATA PARAMS_&DVAR.;
SET PARAMS;
RUN;

/* TRANSPOSE THE INTERCEPT, AND ALL THE VARIABLES IN YOUR MODEL STATEMENT */
PROC TRANSPOSE DATA=PARAMS PREFIX=COEFF OUT=TPARAMS;
BY &BYVAR.;
RUN;

/* CALCULATE SE, T VALUE, AND P VALUE FOR THE T_TEST */
DATA A(KEEP=&BYVAR. PARAMETER COEFF DFC SE TVALUE PVALUE CHISQ CHIVALUE);
  SET TPARAMS;
  PARAMETER = _NAME_;
  ARRAY PARMS(44) COEFF1-COEFF44;
  ARRAY SQDIFF(44) SQDIFF1-SQDIFF44;
    DO I = 1 TO 44;
      SQDIFF(I) = (PARMS(I) - COEFF45)**2;
    END; 
  COEFF = COEFF45;
  DFC = 44;
  SE = SQRT( SUM(OF SQDIFF(*))/44 ); /* HORIZONTAL SUM */
  IF SE GT 0 THEN TVALUE = COEFF/SE;
  ELSE TVALUE = 0;
  PVALUE=(1-PROBT(ABS(TVALUE),44))*2; /* DF=44 */
  CHISQ=TVALUE*TVALUE;
  CHIVALUE=1-PROBCHI(CHISQ,1); /* DF = 1 */
RUN;

%IF (%SUPERQ(XOUTPUT) = YES) OR (%SUPERQ(IMPUTED_VARS) = ) %THEN %DO;
%IF (%SUPERQ(XOUTPUT) = YES) %THEN 
	%LET TITLE8 = "         Independent variables: %EVAL(&IVS. - 1)";
	%ELSE %LET TITLE8 = "         Independent variables: &IV.";;
PROC PRINT DATA=A SPLIT='*' UNIFORM;
  TITLE1 &TITLE1.;
  TITLE2 &TITLE2.;
  TITLE3 &TITLE3.;
  TITLE4 "The LOGISTIC Procedure using replicate weights" ;
  TITLE5 "Balanced Repeated Replication (BRR) method" ;
  TITLE6 "             Response Variable: &DVAR.";
  TITLE7 "Denominator degrees of freedom: 44";
  TITLE8 &TITLE8.;
  TITLE9 "                    Analysis of Maximum Likelihood Estimates";

VAR COEFF SE TVALUE PVALUE CHISQ CHIVALUE;
ID &BYVAR. PARAMETER;
LABEL 
	Parameter = "Parameter  "
	Coeff     = "Estimate   "
	SE        = "Standard * Error  "
	tvalue    = "t Value"
	pvalue    = "Pr > |t|"
	chisq	  = "Chi-Square"
	chivalue  = "Pr > ChiSq"
    ;
RUN;
%END;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE TPARAMS PARAMS1 PARAMS;
QUIT;
%MEND;

/**********************************************************************/
/* THE MACRO UNWT_PROC_LOGISTIC PERFORM LOGISTIC REGRESSIONS          */
/* default for SAS technique=Fisher                                   */
/**********************************************************************/
%MACRO UNWT_PROC_LOGISTIC;
/* RUN MACRO LOGISTIC_OPTIONS */
%LOGISTIC_OPTIONS;

/* RUN LOGISTIC REGRESSION */
%IF (%SUPERQ(XOUTPUT) = YES) OR (%SUPERQ(IMPUTED_VARS) = ) %THEN %DO;
PROC LOGISTIC DATA=MYDATA &OPTIONS.;
BY &BYVAR.;
  TITLE1 &TITLE1.;
  TITLE2 &TITLE2.;
  TITLE3 &TITLE3.;
  TITLE4 "Consumer Expenditure Survey";
  TITLE5 "Dataset &DSN.";
  TITLE6 "Unweighted data";
 CLASS &CLASS.;
 MODEL &DVAR. = &IVARS./technique=Fisher;
RUN;
%END;

/* KEEP THE INTERCEPT AND ALL THE VARIABLES IN YOUR MODEL STATEMENT */
ODS LISTING CLOSE;
ODS OUTPUT PARAMETERESTIMATES=PE(KEEP=&BYVAR. VARIABLE ESTIMATE STDERR)
			MODELINFO = MODELINFO(KEEP=&BYVAR. VALUE DESCRIPTION)
			;
PROC LOGISTIC DATA=MYDATA &OPTIONS.;
BY &BYVAR.;
 CLASS &CLASS.;
 MODEL &DVAR. = &IVARS./technique=Fisher;
QUIT;
ODS LISTING;

DATA A(KEEP=&BYVAR. PARAMETER COEFF SE COUNT);
SET PE;
COEFF=ESTIMATE;
PARAMETER=VARIABLE;
SE=STDERR;
COUNT=1;
RUN;

DATA MODELINFO;
SET MODELINFO;
COUNT =1;
IF DESCRIPTION = 'Number of Observations' THEN OUTPUT MODELINFO;
RUN;

PROC SORT DATA=MODELINFO;
BY COUNT &BYVAR.;
RUN;

PROC SORT DATA=MODELINFO;
BY COUNT &BYVAR.;
RUN;

DATA A;
MERGE A MODELINFO;
BY COUNT &BYVAR.; 
SS = VALUE;
RUN;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE PE MODELINFO LEVELS;
QUIT;
%MEND;

/*********************************************************************/
/* MACRO REGRESSIONS                                                 */
/*********************************************************************/
%MACRO REGRESSIONS;

%LET DSN = %UPCASE(&DSN);
%LET USE_WEIGHTS = %UPCASE(&USE_WEIGHTS);
%IF (%SUPERQ(USE_WEIGHTS) = ) %THEN %LET USE_WEIGHTS = NO;
%LET BYVAR = %UPCASE(&BYVAR);
%LET DEP_VARS = %UPCASE(&DEP_VARS);
%LET IND_VARS = %UPCASE(&IND_VARS);
%LET IMPUTED_VARS = %UPCASE(&IMPUTED_VARS);
%LET DF = %UPCASE(&DF);
%IF (%SUPERQ(DF) = ) %THEN %LET DF = RUBIN99;
%LET XOUTPUT = %UPCASE(&XOUTPUT);
%IF (%SUPERQ(XOUTPUT) = ) %THEN %LET XOUTPUT = NO;

/* DEFINE GLOBAL MACRO VARIABLES */
%GLOBAL UW;
%LET UW = %UPCASE(&USE_WEIGHTS);
%GLOBAL BY_VAR;
%LET BY_VAR = %UPCASE(&BYVAR);
%GLOBAL DFDEF;
%LET DFDEF = &DF.;

%PUT ;
%PUT Reading the dataset.;
%PUT ;
	%READ_DATA;
%IF (%SUPERQ(IMPUTED_VARS) = ) %THEN %DO;

	* COUNT NUMBER OF DEPENDENT AND INDEPENDENT VARIABLES (DV, IV);
	%COUNT_VARS(&DEP_VARS,DELIM=%STR( ));
	%LET DV = &N_VARS.;
	%COUNT_VARS(&IND_VARS,DELIM=%STR( ));
	%LET IV = &N_VARS.;
	%LET DVARS = &DEP_VARS.;
	%LET IVARS = &IND_VARS.;

	%IF %UPCASE(&USE_WEIGHTS) = YES %THEN %DO;
%PUT ;
%PUT Perform PROC &PROC for weighted non-imputed data.;
%PUT ;
		%DO N = 1 %TO &DV ;
		%WT_PROC_&PROC.;
		DATA DEP_VAR_&DVAR.;
		SET A;
		RUN;
		%END;
	%END;
	%ELSE %IF %UPCASE(&USE_WEIGHTS) = NO %THEN %DO;
%PUT ;
%PUT Perform PROC &PROC for unweighted non-imputed data.;
%PUT ;
		%DO N = 1 %TO &DV ;
		%UNWT_PROC_&PROC.;
		DATA DEP_VAR_&DVAR.;
		SET A;
		RUN;
		%END;	
	%END;
%END;
%ELSE %DO;

DATA IMPVARS(KEEP=&IMPUTED_VARS.);
SET MYDATA(OBS=1);
RUN;

PROC TRANSPOSE DATA=IMPVARS OUT=IMPVAR(KEEP=_NAME_);
VAR &IMPUTED_VARS.;
RUN;

%LET VRS = ;
proc sql noprint;
 SELECT distinct _NAME_ INTO: VRS SEPARATED BY ' ' 
 FROM IMPVAR;
QUIT;
%LET VRS = %UPCASE(&VRS);

/*COUNT THE NUMBER OF IMPUTED VARIABLES*/
	%COUNT_VARS(&VRS.,DELIM=%STR( ));
	%LET AV = &N_VARS.;
	%LET IMPUTED_VARS = ;
%DO C=1 %TO &AV. %BY 5;
    %LET IMPV1 = %SCAN(&VRS., &C, ' ');
    %LET C2=%EVAL(&C + 1);
    %LET IMPV2 = %SCAN(&VRS., &C2., ' ');
    %LET C3=%EVAL(&C + 2);
    %LET IMPV3 = %SCAN(&VRS., &C3., ' ');
    %LET C4=%EVAL(&C + 3);
    %LET IMPV4 = %SCAN(&VRS., &C4., ' ');
    %LET C5=%EVAL(&C + 4);
    %LET IMPV5 = %SCAN(&VRS., &C5., ' ');

	%LET VRS&C. = &IMPV1. &IMPV2. &IMPV3. &IMPV4. &IMPV5.;
	%LET IMPVAR&C. = &IMPV1.-&IMPV5.;
	%LET IMPVAR_&C. = &IMPV1._&IMPV5.;
	%LET IMPUTED_VARS = &IMPUTED_VARS. &&IMPVAR&C.;
%END;

	* COUNT NUMBER OF DEPENDENT AND INDEPENDENT VARIABLES (DV, IV);
	%COUNT_VARS(&DEP_VARS,DELIM=%STR( ));
	%LET DV = &N_VARS.;
	%COUNT_VARS(&IND_VARS,DELIM=%STR( ));
	%LET IV = &N_VARS.;
		* IV: NUMBER OF INDEPENDENT VARIABLES IN THE MODEL;
		* AV: NUMBER OF IMPUTED VARIABLES IN THE MODEL;
	%lET IVS = %EVAL(&IV. + 1 + (&AV./5));
	%LET IV = %EVAL(&IV. + &AV.);
	%LET DVARS = &DEP_VARS.;

%DO N = 1 %TO &DV ;
%DO IMP = 1 %TO 5;
	%LET IVARS = &IND_VARS.;
%DO C = 1 %TO &AV. %BY 5;
	%LET IMPUTED_VAR=%SCAN(&&VRS&C., &IMP. );
	%LET IMP_VAR&C.=&IMPUTED_VAR.;
	%LET IVARS = &IVARS. &IMPUTED_VAR.;
%END;

* CALL MACROS TO PERFORM REGRESSIONS ;
	%IF %UPCASE(&USE_WEIGHTS) = YES %THEN %DO;
%PUT ;
%PUT Perform PROC &PROC for weighted MI data.;
%PUT ;
		%WT_PROC_&PROC.;	
		DATA PARAMS;
		SET PARAMS_&DVAR.;
		IMPUTATION = &IMP.; 
			%DO C=1 %TO &AV. %BY 5;
			%LET OLDNAME = %SCAN(&&VRS&C., &IMP. );
			%LET NEWNAME = &&IMPVAR_&C.;
			RENAME &OLDNAME. = &NEWNAME.;
			%END;	
		RUN;

		PROC APPEND BASE=PARAMS_ALL&DVAR. DATA=PARAMS FORCE;
		RUN;
	%END;
	%ELSE %IF %UPCASE(&USE_WEIGHTS) = NO %THEN %DO;
%PUT ;
%PUT Perform PROC &PROC for unweighted MI data.;
%PUT ;
		%UNWT_PROC_&PROC.;
	%END;

/*   Degrees of Freedom: SS - IVS                     */
/*   IVS is the number of independent variables       */
/*	 in the model including the intercept             */
DATA VAR&IMP.(KEEP=&BYVAR. VARIABLE VAR&IMP. MEAN&IMP. DFC&IMP.);
ATTRIB VARIABLE LENGTH=$40;
SET A;
VARIABLE=PARAMETER;
VAR&IMP.=SE*SE;
DFC&IMP.= SS - &IVS.;
MEAN&IMP.=COEFF;
%DO C = 1 %TO &AV. %BY 5;
IF VARIABLE = "&&&IMP_VAR&C." THEN VARIABLE = "&&&IMPVAR&C.";
%END;
RUN;

PROC SORT DATA=VAR&IMP.;
BY &BYVAR. VARIABLE;
RUN;
%END;

	%IF %UPCASE(&USE_WEIGHTS) = YES %THEN %DO;
	DATA PARAMS4WTMI_&DVAR.;
	SET PARAMS_ALL&DVAR.;
	RUN;

	PROC DATASETS LIBRARY=WORK NOLIST;
	DELETE PARAMS PARAMS_ALL&DVAR. PARAMS_&DVAR.;
	QUIT;

	%IF (%SUPERQ(BY_VAR) NE ) %THEN %DO;
	PROC SORT DATA=PARAMS4WTMI_&DVAR.;
	BY &BYVAR. IMPUTATION;
	RUN;
	%END;
	%END;

DATA TOT_VAR;
MERGE VAR1 VAR2 VAR3 VAR4 VAR5;
BY &BYVAR. VARIABLE;
RUN;

%PUT ;
%PUT Calculate total variance for multiply imputed data.;
%PUT ;
/* CALCULATE THE TOTAL VARIANCE FOR ALL GROUPS OF 5 IMPUTED VARIABLES */
	%TOT_VAR;

/* RM = RELATIVE INCREASE OF VARIANCE DUE TO NONRESPONSE */
DATA TOT_VARS(DROP=DFC1-DFC5);
SET TOT_VARS;
  DFC = DFC1;
  SE = SQRT(TVAR);
  TVALUE = MEAN_MEANS/SE;
%IF &PROC. = LOGISTIC %THEN %DO;
  CHISQ=TVALUE*TVALUE;
  CHIVALUE=1-PROBCHI(CHISQ,1); /* DF = 1 */
%END;
/* DF from RUBINS book 1987, page 77*/
  RM = (1.2*VAR_MEANS)/MEAN_VARS;
  DFM = 4*(1+(1/RM))**2;
/* What definition to use? Rubin87(DFM) or Rubin99(DDF)*/
%IF &DF. = RUBIN87 %THEN  DDF = DFM;
%ELSE %IF &DF. = RUBIN99 %THEN %DO;
/* DF from SUDAAN Language manual, page 89 Rubin definition 1999*/
/* VDF [(DFC+1 / DFC+3)]*[(1- [(5+1)*VAR_MEANS]/5*TVAR)]*DFC */
/* DDF = 1/ [(1/DF) + (1/VDF)]*/
  %IF &USE_WEIGHTS. = YES %THEN DFC = 44;;
  VDF = ((DFC+1)/(DFC+3))*(1-((6*VAR_MEANS)/(5*TVAR)))*DFC;
  DDF = 1/((1/DFM)+(1/VDF)); 
%END;;

    PVALUE = (1-PROBT(ABS(TVALUE),DDF))*2; 
	/* ROUND DF */
	DF = ROUND(DDF,1);
RUN;

/* GET INDEPENDENT VARIABLE NAMES TO SORT FINAL DATASET */
PROC CONTENTS DATA = MYDATA (KEEP = &IND_VARS.) NOPRINT
  OUT = VARNAME;
RUN;
%LET INDVARS = ;
PROC SQL NOPRINT;
 SELECT NAME INTO: INDVARS SEPARATED BY '", "' 
 FROM VARNAME WHERE TYPE = 1;
QUIT;

* COUNT THE NUMBER OF IMPUTED VARIABLES (AV);
	%COUNT_VARS(&IMPUTED_VARS,DELIM=%STR( ));
    %LET AV = %EVAL(5*&N_VARS);

DATA TOT_VARS;
SET TOT_VARS;
ORDER = '1';
IF VARIABLE IN("&INDVARS.") THEN ORDER='2';
%DO C=1 %TO &AV. %BY 5;
	%LET IVAR = &&&IMPVAR&C.;
	IF VARIABLE = "&IVAR." THEN ORDER='3';
%END;
RUN;

PROC SORT DATA=TOT_VARS;
BY &BYVAR. ORDER;
RUN;

DATA DEP_VAR_&DVAR.(DROP=ORDER);
SET TOT_VARS;
RUN;

%GLOBAL TITLE6;
%GLOBAL TITLE8;

%IF %UPCASE(&USE_WEIGHTS) = YES %THEN 
	%LET TITLE6 = Total variance using the BRR method of variance estimation;
    %ELSE %IF %UPCASE(&USE_WEIGHTS) = NO %THEN 
	%LET TITLE6 = Total variance for unweighted data;

%IF %UPCASE(&DF) = RUBIN99 %THEN 
	%LET TITLE8 = Degrees of Freedom: Barnard & Rubin (1999) definition;
    %ELSE %IF %UPCASE(&DF) = RUBIN87 %THEN 
    %LET TITLE8 = Degrees of Freedom: Rubin (1987) definition;
%END;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE VAR1-VAR5 VARNAME TOT_VARS;
QUIT;
%END;
%MEND;

/*********************************************************************/
/* MACRO PROC_REG                                                    */
/*********************************************************************/
/**********************************************************************/
/* DSN:          DATASET NAME                                         */
/* FORMAT:       FORMATS IF ANY							              */
/* USE_WEIGHTS:  YES OR NO (DEFAULT = NO)				              */
/* BYVAR:  		 BY VARIABLES IF ANY								  */
/* DEP_VARS:     DEPENDENT VARIABLE FOR YOUR MODEL                    */
/* IND_VARS:     INDEPENDENT VARIABLES FOR YOUR MODEL                 */
/* IMPUTED_VARS: IMPUTED VARIABLES FOR YOUR MODEL                     */
/* DF:  		 DEGREES OF FREEDOM DEFINITION                        */
/*								(DEFAULT IS RUBIN99)		          */
/*                              (OPTION IS RUBIN 87)                  */
/* TITLE1:  	 TITLE 1 FOR OUTPUT								  	  */
/* TITLE2:  	 TITLE 2 FOR OUTPUT								  	  */
/* TITLE3:  	 TITLE 3 FOR OUTPUT								  	  */
/* XOUTPUT       PRINT EXTRA OUTPUT                                   */
/**********************************************************************/
%MACRO PROC_REG(DSN = , 
  			 FORMAT = , 
		USE_WEIGHTS = ,
		      BYVAR = ,
		   DEP_VARS = , 
		   IND_VARS = , 
	   IMPUTED_VARS = ,
	             DF = ,
		     TITLE1 = ,
			 TITLE2 = ,
			 TITLE3 = ,
  		    XOUTPUT = );

/* DEFINE GLOBAL MACRO VARIABLES */
%GLOBAL MI_REG_VARS;  
%LET MI_REG_VARS = %UPCASE(&IMPUTED_VARS);
%GLOBAL REGRESSION;
%LET REGRESSION = YES;	
%GLOBAL LOGISTIC;
%LET LOGISTIC = ;	

%LET PROC = REG;

%REGRESSIONS;

%IF (%SUPERQ(IMPUTED_VARS) NE ) %THEN %DO;
	PROC PRINT DATA=DEP_VAR_&DVAR. SPLIT='*' UNIFORM;
	TITLE1 &TITLE1.;
	TITLE2 &TITLE2.;
	TITLE3 &TITLE3.;
	TITLE4 "Consumer Expenditure Survey: Dataset &DSN.";
	TITLE5 "Collection year estimates for imputed data";
	TITLE6 &TITLE6.;
	TITLE7 "Regression for Dependent Variable: &DVAR.";
    TITLE8 &TITLE8.;
    TITLE9 "                  Parameter Estimates";
	ID &BYVAR. VARIABLE;
	VAR DF MEAN_MEANS SE TVAR TVALUE PVALUE;
	LABEL 
		VARIABLE   = "Variable  "
		MEAN_MEANS = "Parameter *Estimate "
		SE         = " Standard *  Error  "
		TVALUE     = "t Value"
		PVALUE     = "Pr > |t|"
		TVAR 	   = "    Total * Variance"
		;
	RUN;
%END;

TITLE;
%MEND;

/*********************************************************************/
/* MACRO PROC_LOGISTIC                                               */
/*********************************************************************/
/**********************************************************************/
/* DSN:          DATASET NAME                                         */
/* FORMAT:       FORMATS IF ANY							              */
/* USE_WEIGHTS:  YES OR NO (DEFAULT = NO)				              */
/* BYVAR:  		 BY VARIABLES IF ANY							      */
/* DEP_VARS:     DEPENDENT VARIABLE FOR YOUR MODEL                    */
/* IND_VARS:     INDEPENDENT VARIABLES FOR YOUR MODEL                 */
/* IMPUTED_VARS: IMPUTED VARIABLES FOR YOUR MODEL                     */
/* DF:  		 DEGREES OF FREEDOM DEFINITION                        */
/*								(DEFAULT IS RUBIN99)		          */
/*                              (OPTION IS RUBIN 87)                  */
/* SORT_ORDER:   SORTING ORDER OF DEPENDENT VARIABLE                  */
/* CLASSVARS:    													  */
/*    INDEPENDENT CLASSIFICATION VARIABLES AND SORTING OPTIONS IF ANY */
/* TITLE1:  	 TITLE 1 FOR OUTPUT									  */
/* TITLE2:  	 TITLE 2 FOR OUTPUT									  */
/* TITLE3:  	 TITLE 3 FOR OUTPUT									  */
/* XOUTPUT       PRINT EXTRA OUTPUT                                   */
/**********************************************************************/
%MACRO PROC_LOGISTIC(DSN = , 
  				  FORMAT = , 
			 USE_WEIGHTS = ,
		           BYVAR = ,
				DEP_VARS = , 
				IND_VARS = , 
			IMPUTED_VARS = , 
			          DF = ,
			  SORT_ORDER = , 
			   CLASSVARS = ,
				  TITLE1 = ,
                  TITLE2 = ,
                  TITLE3 = ,
  		         XOUTPUT = );

%LET SORT_ORDER = %UPCASE(&SORT_ORDER);
%LET CLASSVARS = %UPCASE(&CLASSVARS);

/* DEFINE GLOBAL MACRO VARIABLES */
%GLOBAL MI_LOGISTIC_VARS;  
%LET MI_LOGISTIC_VARS = %UPCASE(&IMPUTED_VARS);
%GLOBAL REGRESSION;
%LET REGRESSION = ;
%GLOBAL LOGISTIC;
%LET LOGISTIC = YES;	

%LET PROC = LOGISTIC;

%REGRESSIONS;


%IF (%SUPERQ(IMPUTED_VARS) NE ) %THEN %DO;
%IF %UPCASE(&USE_WEIGHTS) = YES %THEN 
		%LET TITLE7 = Response Variable: &DVAR.;
%ELSE %IF %UPCASE(&USE_WEIGHTS) = NO %THEN 
		%LET TITLE7 = Dependent Variable: &DVAR.;

	PROC PRINT DATA=DEP_VAR_&DVAR. SPLIT='*' UNIFORM;
    TITLE1 &TITLE1.;
    TITLE2 &TITLE2.;
    TITLE3 &TITLE3.;
	TITLE4 "Consumer Expenditure Survey, Dataset &DSN.";
	TITLE5 "Collection year estimates for imputed data";
	TITLE6 &TITLE6.;
	TITLE7 &TITLE7.;
    TITLE8 &TITLE8.;
    TITLE9 "                  Analysis of Maximum Likelihood Estimates";
	ID &BYVAR. VARIABLE;
	VAR DF MEAN_MEANS SE TVAR TVALUE PVALUE CHISQ CHIVALUE;
	LABEL 
		VARIABLE     = "Parameter  "
		MEAN_MEANS   = "Estimate"
		SE           = "Standard   *Error  "
		tvalue       = "t Value"
		pvalue       = "Pr > |t|"
 		TVAR 	     = "    Total  * Variance"
	chisq	  = "Chi-Square"
	chivalue  = "Pr > ChiSq"
    ;
	RUN;
%END;
PROC DATASETS LIBRARY=WORK NOLIST;
DELETE A;
QUIT;

TITLE;
%MEND;

/**********************************************************************/
/**********************************************************************/
/* THE MACROS COMPARE, F_TEST, AND CHISQ_TEST                         */
/* PERFORM COMPARISON OF THE REGRESSION PARAMETER ESTIMATES           */
/* PE1 AND PE2 ARE THE PARAMETER ESTIMATES TO BE COMPARE              */
/* EQUIVALENT TO SAS STATEMENT: TEST PE1 = PE2                        */
/**********************************************************************/
/**********************************************************************/
%MACRO COMPARE_PARAMS(PE1, PE2);
/* COMPARE FOR WEIGHTED NONIMPUTED DATA */

%IF &UW. = YES AND (%SUPERQ(MI_VARS ) = ) %THEN %DO;
%PUT ;
%PUT Perform parameter comparisons for weighted non-imputed data.;
%PUT ;

DATA PARAM(KEEP=&PE1._VS_&PE2. &BY_VAR.);
SET PARAMS_&DVAR.;
&PE1._vs_&PE2. = &PE1 - &PE2 ;
RUN;

/* TRANSPOSE THE VARIABLE &PE1._&PE2. */
PROC TRANSPOSE DATA=PARAM PREFIX=COEFF OUT=TPARAMS;
BY &BY_VAR.;
RUN;

DATA TPARAMS;
ATTRIB _NAME_ LENGTH=$40;
SET TPARAMS;
RUN;

PROC APPEND BASE=TPARAMS2 DATA=TPARAMS FORCE;
RUN;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE PARAM TPARAMS;
QUIT;
%END;
/* COMPARE FOR WEIGHTED IMPUTED DATA */
%IF &UW. = YES AND (%SUPERQ(MI_VARS ) NE ) %THEN %DO;
%PUT ;
%PUT Perform parameter comparisons for weighted MI data.;
%PUT ;

DATA PARAM;
SET PARAMS4WTMI_&DVAR.;
/* IDENTIFY VARIABLES OF MULTIPLY IMPUTED DATA (DASH IN THE NAME) */
RX = RXPARSE("$'-'");
   match=rxmatch(rx,"&PE1.");
   IF MATCH GT 0 THEN DO;
   call rxsubstr(rx,"&PE1.",position1);
   position2=position1-1;
	vr1=substr("&PE1.",1,position2);
	position3=position1+1;
	vr2=substr("&PE1.",position3,position2);
	PE1=trim(vr1)||'_'||trim(vr2);
	PEN1=SUBSTR(PE1,1,14);
	END;
	ELSE DO;
		PE1 = "&PE1.";
		PEN1 = "&PE1.";
		END;
RX = RXPARSE("$'-'");
   match=rxmatch(rx,"&PE2.");
   IF MATCH GT 0 THEN DO;
   call rxsubstr(rx,"&PE2.",position1);
   position2=position1-1;
	vr1=substr("&PE2.",1,position2);
	position3=position1+1;
	vr2=substr("&PE2.",position3,position2);
	PE2=trim(vr1)||'_'||trim(vr2);
	PEN2=SUBSTR(PE2,1,14);
	END;
	ELSE DO;
		PE2 = "&PE2.";
		PEN2 = "&PE2.";
		END;
RUN;

%LET XPE1 = ;
%LET XPE2 = ;
%LET XPEN1 = ;
%LET XPEN2 = ;

PROC SQL NOPRINT;
 SELECT DISTINCT PE1, PE2, PEN1, PEN2 
	INTO :XPE1, :XPE2, :XPEN1, :XPEN2 
    FROM PARAM;
   QUIT;
   RUN;

%LET XPE1 = %QTRIM(&XPE1.);
%LET XPE2 = %QTRIM(&XPE2.);
%LET XPEN1 = %QTRIM(&XPEN1.);
%LET XPEN2 = %QTRIM(&XPEN2.);

%LET VARIABLE = %QTRIM(&XPEN1._vs_&XPEN2.); 
DATA PARAM;
SET PARAM;
&VARIABLE. = &XPE1. - &XPE2. ;
RUN;

PROC TRANSPOSE DATA=PARAM prefix=diff OUT=TYS;
BY &BY_VAR. IMPUTATION;
var &VARIABLE.;
RUN;

data TYS;
set TYS;
  ARRAY diff(44) diff1-diff44;
  ARRAY SQDIFF(44) SQDIFF1-SQDIFF44;
    DO I = 1 TO 44;
      SQDIFF(I) = (diff(I) - diff45)**2;
      DROP I; 
    END; 
  MEAN = diff45;
  VARIANCE = SUM(OF SQDIFF(*))/44;
run;

DATA TYS(KEEP=&BY_VAR. IMPUTATION _name_ MEAN VARIANCE);
SET TYS;
RUN;

PROC TRANSPOSE DATA=TYS OUT=TM PREFIX=MEAN;
VAR MEAN;
BY &BY_VAR.;
RUN;

PROC TRANSPOSE DATA=TYS OUT=TV PREFIX=VAR;
VAR VARIANCE;
BY &BY_VAR.;
RUN;

DATA TALL(DROP=_NAME_ );
ATTRIB Compare_Coeff LENGTH=$40.;
MERGE TM TV;
Compare_Coeff="&PE1._vs_&PE2.";
RUN;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE PARAM TYS TM TV;
QUIT;
%END;
/* COMPARE FOR UNWEIGHTED IMPUTED DATA */
%ELSE %IF &UW. = NO %THEN %DO;
%PUT ;
%PUT Perform parameter comparisons for unweighted MI data.;
%PUT ;

DATA TY1(KEEP= &BY_VAR. VARIABLE MEAN_MEANS TVAR DF);
SET DEP_VAR_&DVAR.;
%IF &DFDEF. = RUBIN87 %THEN  DF=DFM;;
%IF &DFDEF. = RUBIN99 %THEN  DF=DDF;;
IF VARIABLE IN("&PE1.", "&PE2.") THEN OUTPUT TY1;
RUN;

%IF (%SUPERQ(BY_VAR) NE ) %THEN %DO;
PROC SORT DATA=TY1;
BY &BY_VAR.;
RUN;
%END;

PROC TRANSPOSE DATA=TY1 PREFIX=TVAR OUT=ZSCY;
BY &BY_VAR.;
VAR TVAR;
RUN;

PROC TRANSPOSE DATA=TY1 PREFIX=MEAN OUT=ZSCZ;
BY &BY_VAR.;
VAR MEAN_MEANS;
RUN;

PROC TRANSPOSE DATA=TY1 PREFIX=DF OUT=ZSCDF;
BY &BY_VAR.;
VAR DF;
RUN;

/* CALCULATE THE T_STAT VALUES */
DATA ZSALL;
ATTRIB Compare_Means LENGTH=$60;
MERGE ZSCZ ZSCY ZSCDF;
BY &BY_VAR.;
Compare_Means="&PE1._vs_&PE2.";
RUN;

PROC APPEND BASE=TY2 DATA=ZSALL FORCE;
RUN;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE TY1 ZSCY ZSCZ ZSCDF ZSALL;
QUIT;
%END;
%MEND;

/****************************************************************/
/* MACRO COMPARE_PE                                             */
/****************************************************************/
/****************************************************************/
/* DEP_VAR:      DEPENDENT VARIABLE 					        */
/* PE:           PARAMETER ESTIMATE TO BE COMPARE				*/
/* TITLE1:  	 TITLE 1 FOR OUTPUT							    */
/* TITLE2:  	 TITLE 2 FOR OUTPUT							    */
/* TITLE3:  	 TITLE 3 FOR OUTPUT							    */
/****************************************************************/
/****************************************************************/
/* COMPARE PARAMETER ESTIMATES                                  */
/* FOR NON MI WEIGHTED DATA							            */
/****************************************************************/

%MACRO COMPARE_PE(DEP_VAR = ,
					   PE = ,
			       TITLE1 = ,
			       TITLE2 = ,
			       TITLE3 = );

OPTIONS PAGENO=1 NOCENTER;

%LET TITLE1 = ;
%LET TITLE2 = ;
%LET TITLE3 = ;
%LET DVAR = %UPCASE(&DEP_VAR);
%LET PE = %UPCASE(&PE);

%LET PROC_REGRESSION = %UPCASE(&REGRESSION);
%LET PROC_LOGISTIC = %UPCASE(&LOGISTIC);

	%IF &PROC_REGRESSION. = YES %THEN %LET MI_VARS = &MI_REG_VARS.;
	%ELSE %IF &PROC_LOGISTIC. = YES %THEN %LET MI_VARS = &MI_LOGISTIC_VARS.;;

%IF (%SUPERQ(MI_VARS ) = ) AND &UW. = NO %THEN %DO; 
%PUT ERROR: This program does not perform comparisons for non-imputed unweighted data.;
%END;
%ELSE %DO;
	%COUNT_VARS(&PE.,DELIM=%STR( ));
	%LET C_PE = &N_VARS.;
		%DO CPE=1 %TO &C_PE. %BY 2;
			%LET PE1 = %SCAN(&PE., &CPE, ' ');
			%LET CPE2 = %EVAL(&CPE + 1);
			%LET PE2 = %SCAN(&PE., &CPE2, ' ');
* CALL MACRO COMPARE TO PERFORM COMPARISONS BETWEEN;
* PARAMETER ESTIMATES AS MANY TIMES AS NECESARY;
			%COMPARE_PARAMS(&PE1., &PE2.);
				%IF (%SUPERQ(MI_VARS )NE ) AND &UW. = YES %THEN %DO;				
				PROC APPEND BASE=TY2 DATA=TALL FORCE;
				RUN;
				PROC DATASETS LIBRARY=WORK NOLIST;
				DELETE TALL;
				QUIT;
				%END;
		%END;

%IF (%SUPERQ(MI_VARS )NE ) AND &UW. = YES %THEN %DO;
DATA B (DROP = Compare_Coeff MEAN1-MEAN5 VAR1-VAR5);
ATTRIB _NAME_ LENGTH=$60;
SET TY2;
_NAME_ = Compare_Coeff;
* CALCULATE COMPLETE DATASET STATISTICS;
Coeff=MEAN(OF MEAN1-MEAN5);
Mean_Vars=MEAN(OF VAR1-VAR5);
SUMSQRD=0;
%DO I=1 %TO 5;
    SUMSQRD=SUM(SUMSQRD,((MEAN&I.-Coeff)**2));
%END;
Var_Coeff=SUMSQRD/4;
TVAR = MEAN_VARS + (1.2*VAR_Coeff);
SE_Coeff = SQRT(TVAR);
IF SE_Coeff NE 0 THEN TValue = Coeff/SE_Coeff;
ELSE TValue = .;
Test = TVALUE*TVALUE;

RM = (1.2*VAR_Coeff)/MEAN_VARS;
DFM = 4*(1+(1/RM))**2;
%IF &DFDEF. = RUBIN87 %THEN DFF = DFM;
%ELSE %IF &DFDEF. = RUBIN99 %THEN %DO;
	VDF = (45/47)*(1-((6*VAR_Coeff)/(5*TVAR)))*44;
  	DFF = 1/((1/DFM)+(1/VDF)); 
	%END;;

P_Value=1-PROBF(TEST,1,DFF);
DF_Coeff = ROUND(DFF,1);
  CHIVALUE=1-PROBCHI(TEST,1); /* DF = 1 */
  DF=1;
RUN;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE TY2;
QUIT;
%END;

%ELSE %IF (%SUPERQ(MI_VARS ) = ) %THEN %DO;
DATA B;
  SET TPARAMS2;
  PARAMETER = _NAME_;
  ARRAY PARMS(44) COEFF1-COEFF44;
  ARRAY SQDIFF(44) SQDIFF1-SQDIFF44;
    DO I = 1 TO 44;
      SQDIFF(I) = (PARMS(I) - COEFF45)**2;
    END; 
  COEFF = COEFF45;
  SE = SQRT( SUM(OF SQDIFF(*))/44 ); /* HORIZONTAL SUM */
  TVALUE = COEFF/SE;
  TEST=TVALUE*TVALUE;
  P_VALUE=1-PROBF(TEST,1,44);/* DF = 1, 44 */
  CHIVALUE=1-PROBCHI(TEST,1); /* DF = 1 */
  DF=1;
RUN;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE TPARAMS2;
QUIT;
%END;

%ELSE %IF (%SUPERQ(MI_VARS ) NE )%THEN %DO;
DATA B
   (KEEP= &BY_VAR. _NAME_ COEFF Var_Coeff_Diff TVALUE TEST DF DFC P_VALUE CHIVALUE);
ATTRIB _NAME_ LENGTH=$40;
SET TY2;
_NAME_ = Compare_Means;
Coeff = MEAN1 - MEAN2;
DFC = DF1 + DF2; /* DF FOR P_VALUE (OLS) */
Var_Coeff_Diff = TVAR1 + TVAR2;
TVALUE = Coeff / SQRT(Var_Coeff_Diff);
TEST = TVALUE*TVALUE;
  P_VALUE=1-PROBF(TEST,1,DFC);
  CHIVALUE=1-PROBCHI(TEST,1); 
  DF=1; /* DF FOR CHIVALUE (LOGISTIC) */
RUN;

PROC DATASETS LIBRARY=WORK NOLIST;
DELETE TY2;
QUIT;
%END;

%IF &PROC_REGRESSION. = YES %THEN %DO;	
PROC PRINT DATA=B SPLIT='*' UNIFORM;
    TITLE1 &TITLE1.;
    TITLE2 &TITLE2.;
    TITLE3 &TITLE3.;
  TITLE4 "Regression Dependent Variable &DVAR.";
  TITLE5 ;
  TITLE6 "Comparison of Parameter Estimates";

VAR &BY_VAR. COEFF TEST P_VALUE;
ID  _NAME_;
LABEL 
	_NAME_  = "Test"
   	COEFF   = "Coefficient *Difference"
	TEST    = "F Value"
	P_Value = "Pr > F"
    ;
RUN;
%END;

%IF &PROC_LOGISTIC. = YES %THEN %DO;	
PROC PRINT DATA=B SPLIT='*' UNIFORM;
    TITLE1 &TITLE1.;
    TITLE2 &TITLE2.;
    TITLE3 &TITLE3.;
  TITLE4 "Regression for Dependent Variable &DVAR.";
  TITLE5 ;
  TITLE6 "Linear Hypotheses Testing Results";

VAR &BY_VAR. COEFF TEST DF CHIVALUE;
ID  _NAME_;
LABEL 
	_NAME_    = "Test"
   	COEFF     = "Coefficient*Difference"
	TEST      = "       Wald*Chi-Square"
	CHIVALUE  = "Pr > ChiSq"
    ;
RUN;
%END;
%END;

TITLE;
%MEND;

