/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

bool null_present = false;
bool eof = false;
int  nbcnt = 0;
%}

/*
 * Define names for regular expressions here.
 */


TYPE_ID         [A-Z]([A-Za-z0-9_])*
OBJ_ID          [a-z]([A-Za-z0-9_])*

INTEGER         [0-9]+


WHITESPACE      [ \t\f\v\r]+
NEWLINE         "\n"
NULL_CHAR       "\0"
SINGLE_TOKEN    [\+\*\-\~\/\;\(\)\{\}\:\.\@\<\=\,]
INVALID         [^a-zA-Z0-9]
QUOTE           \"
ESCAPE          "\\"
LCOMMENT        "(*"
RCOMMENT        "*)"
LNCOMMENT       "--"

DARROW          =>
ASSIGN          <-
LE              <=

%option noyywrap
%x blockComment lineComment STRING

%%

 /*
  *  Nested comments
  */


{LCOMMENT}                          {BEGIN(blockComment); nbcnt++; }
{RCOMMENT}                          {cool_yylval.error_msg = "unMatched *)"; return ERROR;}
{LNCOMMENT}                         {BEGIN(lineComment); }
<blockComment>{NEWLINE}             {curr_lineno++;}
<blockComment>{LCOMMENT}            {nbcnt++; }
<blockComment>{RCOMMENT}            {nbcnt--; if (nbcnt == 0){  BEGIN(INITIAL);}}
<blockComment>{ESCAPE}.             {}

<blockComment>\([^*]                {}
<blockComment><<EOF>>               {if(!eof){cool_yylval.error_msg = "EOF in comment"; eof = true; return ERROR;}else{return 0;} }

<blockComment>[^*\\(\n]*            { /* eat anything that's not a '*' or '\n' or '\' or '(' */}
<blockComment>\*+[^ \\)\n]*          { /* eat up '*'s not followed by ')' or '\'s */}
<blockComment>\*+\)                 {nbcnt--; if (nbcnt == 0){ BEGIN(INITIAL);}}

<lineComment>{NEWLINE}      {curr_lineno++;BEGIN(INITIAL);}
<lineComment>[^\n]*         { }
<lineComment><<EOF>>        {BEGIN(INITIAL);}


 /*
  *  The multiple-character operators.
  */
{DARROW}		{ return (DARROW);  }
{ASSIGN}        { return (ASSIGN);  }
{LE}            { return (LE);      }
{SINGLE_TOKEN}  { return yytext[0]; }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  *
  */

(?i:class)      return CLASS    ;
(?i:else)       return ELSE     ; 
(?i:fi)         return FI       ; 
(?i:if)         return IF       ;
(?i:in)         return IN       ;
(?i:inherits)   return INHERITS ; 
(?i:let)        return LET      ;
(?i:loop)       return LOOP     ;
(?i:pool)       return POOL     ;
(?i:then)       return THEN     ;
(?i:while)      return WHILE    ;
(?i:case)       return CASE     ;
(?i:esac)       return ESAC     ;
(?i:of)         return OF       ;
(?i:new)        return NEW      ;
(?i:isvoid)     return ISVOID   ;
(?i:not)        return NOT      ;

{WHITESPACE}        { } 
{INTEGER}           {cool_yylval.symbol = inttable.add_string(yytext); return INT_CONST; }         

t[rR][uU][eE]       {cool_yylval.boolean = 1; return BOOL_CONST; } 
f[aA][lL][sS][eE]   {cool_yylval.boolean = 0; return BOOL_CONST; } 
{TYPE_ID}           {cool_yylval.symbol = stringtable.add_string(yytext); return TYPEID; } 
{OBJ_ID}            {cool_yylval.symbol = stringtable.add_string(yytext); return OBJECTID; } 
{NEWLINE}           {curr_lineno++;}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */


{QUOTE}                 {memset(string_buf,0,sizeof(string_buf));string_buf_ptr = string_buf; null_present = 0;  BEGIN(STRING);}
<STRING>{NULL_CHAR}         {null_present = 1; }
<STRING>{NEWLINE}       {curr_lineno++; cool_yylval.error_msg = "Unterminated string constant";  BEGIN(INITIAL);return ERROR;}

<STRING>{ESCAPE}.       {
                             switch(yytext[yyleng-1]){
                                case 'b': *string_buf_ptr = '\b'; break;
                                case 't': *string_buf_ptr = '\t'; break;
                                case 'f': *string_buf_ptr = '\f'; break;
                                case 'n': *string_buf_ptr = '\n'; break;
                                case '0': *string_buf_ptr = '0' ; break;
                                case YY_NULL: null_present = 1;      break;
                                default:  *string_buf_ptr = yytext[yyleng-1]; break;
                             }
                             string_buf_ptr++;  
                        }
<STRING>{ESCAPE}{NEWLINE}  {*string_buf_ptr = '\n';string_buf_ptr++;curr_lineno++;}
<STRING>{QUOTE}         {
                            BEGIN(INITIAL);
                            if (string_buf_ptr-string_buf >= MAX_STR_CONST){
                                cool_yylval.error_msg = "String constant too long";
                                return ERROR;
                            }
                            if (null_present){
                                cool_yylval.error_msg = " String contains null character";
                                return ERROR;
                            }
                            cool_yylval.symbol = stringtable.add_string(string_buf);
                            
                            return STR_CONST;
                        }

<STRING><<EOF>>         {if(!eof){cool_yylval.error_msg = "EOF in string constant"; eof=true;return ERROR;}else{return 0;}}

<STRING>.               {
                            *string_buf_ptr = yytext[0];
                            string_buf_ptr ++;
                        }
{INVALID}               {cool_yylval.error_msg = yytext; return ERROR;}

%%
