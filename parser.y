%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "header.h"
#include "symtab.h"
#include "semcheck.h"

extern int linenum;
extern FILE	*yyin;
extern char	*yytext;
extern char buf[256];
extern int Opt_Symbol;		/* declared in lex.l */

FILE *fout;
int count_stack=1;
int yylex();
int scope = 0;
char fileName[256];
struct SymTable *symbolTable;
__BOOLEAN paramError;
struct PType *funcReturn;
__BOOLEAN semError = __FALSE;
int inloop = 0;
int entrypoint=0;
int true_index = 0;
int false_index = 0;
int if_for_while_index=0;
int index_buffer[1000];
int pointer=0;

int declar_pointer=0;
int declar_buffer[100];
char declar_expr[100][100];
int declar_expr_pointer=0;
SEMTYPE declar_type;
int tem_count_stack;
%}

%union {
	int intVal;
	float floatVal;	
	char *lexeme;
	struct idNode_sem *id;
	struct ConstAttr *constVal;
	struct PType *ptype;
	struct param_sem *par;
	struct expr_sem *exprs;
	struct expr_sem_node *exprNode;
	struct constParam *constNode;
	struct varDeclParam* varDeclNode;
};

%token	LE_OP NE_OP GE_OP EQ_OP AND_OP OR_OP
%token	READ BOOLEAN WHILE DO IF ELSE TRUE FALSE FOR INT PRINT BOOL VOID FLOAT DOUBLE STRING CONTINUE BREAK RETURN CONST
%token	L_PAREN R_PAREN COMMA SEMICOLON ML_BRACE MR_BRACE L_BRACE R_BRACE ADD_OP SUB_OP MUL_OP DIV_OP MOD_OP ASSIGN_OP LT_OP GT_OP NOT_OP

%token <lexeme>ID
%token <intVal>INT_CONST 
%token <floatVal>FLOAT_CONST
%token <floatVal>SCIENTIFIC
%token <lexeme>STR_CONST

%type<ptype> scalar_type 
%type<par> parameter_list
%type<constVal> literal_const
%type<constNode> const_list 
%type<exprs> variable_reference logical_expression logical_term logical_factor relation_expression arithmetic_expression term factor logical_expression_list
%type<intVal> relation_operator add_op mul_op 
%type<varDeclNode> identifier_list


%start program
%%

program :		decl_list 
			    funct_def
				decl_and_def_list 
				{
					checkUndefinedFunc(symbolTable);
					if(Opt_Symbol == 1)
					printSymTable( symbolTable, scope );	
				}
		;

decl_list : decl_list var_decl
		  | decl_list const_decl
		  | decl_list funct_decl
		  |
		  ;


decl_and_def_list : decl_and_def_list var_decl
				  | decl_and_def_list const_decl
				  | decl_and_def_list funct_decl
				  | decl_and_def_list funct_def
				  | 
				  ;

		  
funct_def : scalar_type ID L_PAREN R_PAREN 
			{
				count_stack=1;
				funcReturn = $1; 
				struct SymNode *node;
				node = findFuncDeclaration( symbolTable, $2 );
				
				if( node != 0 ){
					verifyFuncDeclaration( symbolTable, 0, $1, node );
				}
				else{
					insertFuncIntoSymTable( symbolTable, $2, 0, $1, scope, __TRUE );
				}
				if(!strcmp($2,"main"))
				{
					entrypoint=1;
					fprintf(fout,".method public static main([Ljava/lang/String;)V\n");
					fprintf(fout,".limit stack 100\n");
					fprintf(fout,".limit locals 100 \n");
					fprintf(fout,"\tnew java/util/Scanner \n");
					fprintf(fout,"\tdup \n");
					fprintf(fout,"\tgetstatic java/lang/System/in Ljava/io/InputStream;\n");
					fprintf(fout,"\tinvokespecial java/util/Scanner/<init>(Ljava/io/InputStream;)V\n");
					fprintf(fout,"\tputstatic output/_sc Ljava/util/Scanner;\n");
				}
				else
				{
					fprintf(fout,".method public static %s()",$2);
					if($1->type==BOOLEAN_t)
					{
						fprintf(fout,"Z\n");
					}
					if($1->type==FLOAT_t)
					{
						fprintf(fout,"F\n");
					}
					if($1->type==DOUBLE_t)
					{
						fprintf(fout,"D\n");
					}
					if($1->type==INTEGER_t)
					{
						fprintf(fout,"I\n");
					}
					fprintf(fout,".limit stack 100\n");
					fprintf(fout,".limit locals 100 \n");
				}
				
			}
			compound_statement { fprintf(fout, ".end method\n");funcReturn = 0;}	
		  | scalar_type ID L_PAREN parameter_list R_PAREN  
			{		
				count_stack=1;		
				funcReturn = $1;
				paramError = checkFuncParam( $4 );
				if( paramError == __TRUE ){
					fprintf( stdout, "########## Error at Line#%d: param(s) with several fault!! ##########\n", linenum );
					semError = __TRUE;
				}
				// check and insert function into symbol table
				else{
					struct SymNode *node;
					node = findFuncDeclaration( symbolTable, $2 );

					if( node != 0 ){
						if(verifyFuncDeclaration( symbolTable, $4, $1, node ) == __TRUE){	
							insertParamIntoSymTable( symbolTable, $4, scope+1 );
						}				
					}
					else{
						insertParamIntoSymTable( symbolTable, $4, scope+1 );				
						insertFuncIntoSymTable( symbolTable, $2, $4, $1, scope, __TRUE );
					}
				}
				if(!strcmp($2,"main"))
				{
					entrypoint=1;
					fprintf(fout,".method public static main([Ljava/lang/String;)V\n");
					fprintf(fout,".limit stack 100\n");
					fprintf(fout,".limit locals 100 \n");
					fprintf(fout,"\tnew java/util/Scanner \n");
					fprintf(fout,"\tdup\n");
					fprintf(fout,"\tgetstatic java/lang/System/in Ljava/io/InputStream;\n");
					fprintf(fout,"\tinvokespecial java/util/Scanner/<init>(Ljava/io/InputStream;)V\n");
					fprintf(fout,"\tputstatic output/_sc Ljava/util/Scanner;\n");
				}
				else
				{
					fprintf(fout,".method public static %s(",$2);
					struct param_sem *parPtr;
					struct idNode_sem *idPtr;
					for( parPtr=$4 ; parPtr!=0 ; parPtr=(parPtr->next) ) 
					{
						for(idPtr=(parPtr->idlist);idPtr!=0;idPtr=(idPtr->next) ) 
						{
							if(parPtr->pType->type==INTEGER_t)
							{
								fprintf(fout,"I");
							}
							if(parPtr->pType->type==BOOLEAN_t)
							{
								fprintf(fout,"B");
							}
							if(parPtr->pType->type==DOUBLE_t)
							{
								fprintf(fout,"D");
							}
							if(parPtr->pType->type==BOOLEAN_t)
							{
								fprintf(fout,"B");
							}								
						}
						
					}
					fprintf(fout,")");
					if($1->type==BOOLEAN_t)
					{
						fprintf(fout,"Z\n");
					}
					if($1->type==FLOAT_t)
					{
						fprintf(fout,"F\n");
					}
					if($1->type==DOUBLE_t)
					{
						fprintf(fout,"D\n");
					}
					if($1->type==INTEGER_t)
					{
						fprintf(fout,"I\n");
					}
					fprintf(fout,".limit stack 100\n");
					fprintf(fout,".limit locals 100 \n");
				}
				
			} 	
			compound_statement { fprintf(fout, ".end method\n");funcReturn = 0; }
		  | VOID ID L_PAREN R_PAREN 
			{
				count_stack=1;
				funcReturn = createPType(VOID_t); 
				struct SymNode *node;
				node = findFuncDeclaration( symbolTable, $2 );

				if( node != 0 ){
					verifyFuncDeclaration( symbolTable, 0, createPType( VOID_t ), node );					
				}
				else{
					insertFuncIntoSymTable( symbolTable, $2, 0, createPType( VOID_t ), scope, __TRUE );	
				}
				if(!strcmp($2,"main"))
				{
					fprintf(fout,".method public static main([Ljava/lang/String;)V\n");
					fprintf(fout,".limit stack 100\n");
					fprintf(fout,".limit locals 100 \n");
					fprintf(fout,"\tnew java/util/Scanner \n");
					fprintf(fout,"\tdup\n");
					fprintf(fout,"\tgetstatic java/lang/System/in Ljava/io/InputStream;\n");
					fprintf(fout,"\tinvokespecial java/util/Scanner/<init>(Ljava/io/InputStream;)V\n");
					fprintf(fout,"\tputstatic output/_sc Ljava/util/Scanner;\n");
				}
				else
				{
					fprintf(fout,".method public static %s()V\n",$2);
					fprintf(fout,".limit stack 100\n");
					fprintf(fout,".limit locals 100 \n");
				}
			}
			compound_statement { funcReturn = 0;fprintf(fout, "\treturn\n");fprintf(fout, ".end method\n");}	
		  | VOID ID L_PAREN parameter_list R_PAREN
			{	
				count_stack=1;								
				funcReturn = createPType(VOID_t);
				
				paramError = checkFuncParam( $4 );
				if( paramError == __TRUE ){
					fprintf( stdout, "########## Error at Line#%d: param(s) with several fault!! ##########\n", linenum );
					semError = __TRUE;
				}
				// check and insert function into symbol table
				else{
					struct SymNode *node;
					node = findFuncDeclaration( symbolTable, $2 );

					if( node != 0 ){
						if(verifyFuncDeclaration( symbolTable, $4, createPType( VOID_t ), node ) == __TRUE){	
							insertParamIntoSymTable( symbolTable, $4, scope+1 );				
						}
					}
					else{
						insertParamIntoSymTable( symbolTable, $4, scope+1 );				
						insertFuncIntoSymTable( symbolTable, $2, $4, createPType( VOID_t ), scope, __TRUE );
					}
				}
				if(!strcmp($2,"main"))
				{
					fprintf(fout,".method public static main([Ljava/lang/String;)V\n");
					fprintf(fout,".limit stack 100\n");
					fprintf(fout,".limit locals 100 \n");
					fprintf(fout,"\tnew java/util/Scanner \n");
					fprintf(fout,"\tdup\n");
					fprintf(fout,"\tgetstatic java/lang/System/in Ljava/io/InputStream;\n");
					fprintf(fout,"\tinvokespecial java/util/Scanner/<init>(Ljava/io/InputStream;)V\n");
					fprintf(fout,"\tputstatic output/_sc Ljava/util/Scanner;\n");
				}
				else
				{
					fprintf(fout,".method public static %s(",$2);
					struct param_sem *parPtr;
					struct idNode_sem *idPtr;
					for( parPtr=$4 ; parPtr!=0 ; parPtr=(parPtr->next) ) 
					{
						
						for(idPtr=(parPtr->idlist);idPtr!=0;idPtr=(idPtr->next) ) 
						{
							if(parPtr->pType->type==INTEGER_t)
							{
								fprintf(fout,"I");
							}
							if(parPtr->pType->type==BOOLEAN_t)
							{
								fprintf(fout,"B");
							}
							if(parPtr->pType->type==DOUBLE_t)
							{
								fprintf(fout,"D");
							}
							if(parPtr->pType->type==BOOLEAN_t)
							{
								fprintf(fout,"B");
							}								
						}
						
					}
					fprintf(fout,")V\n");
					fprintf(fout,".limit stack 100\n");
					fprintf(fout,".limit locals 100 \n");
				}
			} 
			compound_statement { funcReturn = 0; fprintf(fout, "\treturn\n");fprintf(fout, ".end method\n");}		  
		  ;

funct_decl : scalar_type ID L_PAREN R_PAREN SEMICOLON
			{
				insertFuncIntoSymTable( symbolTable, $2, 0, $1, scope, __FALSE );	
			}
		   | scalar_type ID L_PAREN parameter_list R_PAREN SEMICOLON
		    {
				paramError = checkFuncParam( $4 );
				if( paramError == __TRUE ){
					fprintf( stdout, "########## Error at Line#%d: param(s) with several fault!! ##########\n", linenum );
					semError = __TRUE;
				}
				else {
					insertFuncIntoSymTable( symbolTable, $2, $4, $1, scope, __FALSE );
				}
			}
		   | VOID ID L_PAREN R_PAREN SEMICOLON
			{				
				insertFuncIntoSymTable( symbolTable, $2, 0, createPType( VOID_t ), scope, __FALSE );
			}
		   | VOID ID L_PAREN parameter_list R_PAREN SEMICOLON
			{
				paramError = checkFuncParam( $4 );
				if( paramError == __TRUE ){
					fprintf( stdout, "########## Error at Line#%d: param(s) with several fault!! ##########\n", linenum );
					semError = __TRUE;	
				}
				else {
					insertFuncIntoSymTable( symbolTable, $2, $4, createPType( VOID_t ), scope, __FALSE );
				}
			}
		   ;

parameter_list : parameter_list COMMA scalar_type ID
			   {
				struct param_sem *ptr;
				ptr = createParam( createIdList( $4 ), $3 );
				param_sem_addParam( $1, ptr );
				$$ = $1;
			   }
			   | scalar_type ID { $$ = createParam( createIdList( $2 ), $1 ); }
			   ;

var_decl : scalar_type identifier_list SEMICOLON
			{
				int c1=0;
				int c2=declar_expr_pointer-1;
				struct varDeclParam *ptr;
				struct SymNode *newNode;
				for( ptr=$2 ; ptr!=0 ; ptr=(ptr->next) ) {						
					if( verifyRedeclaration( symbolTable, ptr->para->idlist->value, scope ) == __FALSE ) { }
					else {
						if( verifyVarInitValue( $1, ptr, symbolTable, scope ) ==  __TRUE ){	
							newNode = createVarNode( ptr->para->idlist->value, scope, ptr->para->pType );
							insertTab( symbolTable, newNode,count_stack);
							
							if(scope==0)
							{
								if($1->type==INTEGER_t)
								{
									if(declar_buffer[c1]==1)
									{
										fprintf(fout,"%s",declar_expr[c2]);
										c2--;
									}
									if(declar_buffer[c1]==2)
									{
										fprintf(fout,"%s",declar_expr[c2-2]);
										fprintf(fout,"%s",declar_expr[c2-1]);
										c2-=2;
									}
									c1++;
								}
								if($1->type==DOUBLE_t)
								{
									if(declar_buffer[c1]==1)
									{
										fprintf(fout,"%s",declar_expr[c2]);
										c2--;
									}
									if(declar_buffer[c1]==2)
									{
										fprintf(fout,"%s",declar_expr[c2-2]);
										fprintf(fout,"%s",declar_expr[c2-1]);
										c2-=2;
									}
									c1++;
								}
								if($1->type==FLOAT_t)
								{
									if(declar_buffer[c1]==1)
									{
										fprintf(fout,"%s",declar_expr[c2]);
										c2--;
									}
									if(declar_buffer[c1]==2)
									{
										fprintf(fout,"%s",declar_expr[c2-2]);
										fprintf(fout,"%s",declar_expr[c2-1]);
										c2-=2;
									}
									c1++;
								}
								if($1->type==BOOLEAN_t)
								{
									if(declar_buffer[c1]==1)
									{
										fprintf(fout,"%s",declar_expr[c2]);
										c2--;
									}
									if(declar_buffer[c1]==2)
									{
										fprintf(fout,"%s",declar_expr[c2-2]);
										fprintf(fout,"%s",declar_expr[c2-1]);
										c2-=2;
									}
									c1++;
								}
							}
							else
							{
								if(declar_buffer[c1]==1)
								{
									fprintf(fout,"%s",declar_expr[c2]);
									c2--;
								}
								if(declar_buffer[c1]==2)
								{
									fprintf(fout,"%s",declar_expr[c2-2]);
									fprintf(fout,"%s",declar_expr[c2-1]);
									c2-=2;
								}
								c1++;
							}	
							count_stack++;
							
						}
					}
				}
				declar_expr_pointer=0;
				declar_pointer=0;
			}
			;

identifier_list : identifier_list COMMA ID
				{	
					if(scope==0)
					{
						if(declar_type==DOUBLE_t)
						{
							fprintf(fout,".field public static %s D\n",$3);
							
						}
						if(declar_type==FLOAT_t)
						{
							fprintf(fout,".field public static %s F\n",$3);
							
						}
						if(declar_type==INTEGER_t)
						{
							fprintf(fout,".field public static %s I\n",$3);
							
						}
						if(declar_type==BOOLEAN_t)
						{
							fprintf(fout,".field public static %s Z\n",$3);
							
						}
					}
									
					struct param_sem *ptr;	
					struct varDeclParam *vptr;				
					ptr = createParam( createIdList( $3 ), createPType( VOID_t ) );
					vptr = createVarDeclParam( ptr, 0 );	
					addVarDeclParam( $1, vptr );
					$$ = $1;
					declar_buffer[declar_pointer]=0;
					declar_pointer++;
					tem_count_stack++;				
				}
                | identifier_list COMMA ID ASSIGN_OP logical_expression
				{
					struct param_sem *ptr;	
					struct varDeclParam *vptr;				
					ptr = createParam( createIdList( $3 ), createPType( VOID_t ) );
					vptr = createVarDeclParam( ptr, $5 );
					vptr->isArray = __TRUE;
					vptr->isInit = __TRUE;	
					addVarDeclParam( $1, vptr );	
					$$ = $1;
					char qqq[100];
					int tmp;
					int i=1;
					int count=0;
					int count2=0;
					while(tem_count_stack>=i)
					{
						i*=10;
						count2++;
					}
					i/=10;
					tmp=tem_count_stack;
					while(i!=0&&tmp!=0)
					{
						qqq[count]=tmp/i+'0';
						tmp=tmp%i;
						i=i/10;
						count++;
					}
					if(count!=count2)
					{
						int tmp2=count;
						for(int i=0;i<count2-count;i++)
						{
							qqq[tmp2]=0+'0';
							tmp2++;
						}
						qqq[tmp2]='\0';
					}
					else
					{
						qqq[count]='\0';
					}
					if(scope==0)
					{
						if(declar_type==DOUBLE_t&&($5->pType->type==FLOAT_t)||$5->pType->type==DOUBLE_t)
						{
							fprintf(fout,".field public static %s D\n",$3);
							strcpy(declar_expr[declar_expr_pointer],"\tputstatic ");
							strcat(declar_expr[declar_expr_pointer],"output");
							strcat(declar_expr[declar_expr_pointer],"/"); 
							strcat(declar_expr[declar_expr_pointer],$3);
							strcat(declar_expr[declar_expr_pointer]," D\n");
							declar_expr_pointer++;
							declar_buffer[declar_pointer]=1;
							declar_pointer++;
						}
						if((declar_type==FLOAT_t||declar_type==DOUBLE_t)&&$5->pType->type==INTEGER_t)
						{
							fprintf(fout,".field public static %s F\n",$3);
							strcpy(declar_expr[declar_expr_pointer],"\ti2f\n");
							declar_expr_pointer++;
							strcpy(declar_expr[declar_expr_pointer],"\tputstatic ");
							strcat(declar_expr[declar_expr_pointer],"output");
							strcat(declar_expr[declar_expr_pointer],"/"); 
							strcat(declar_expr[declar_expr_pointer],$3);
							strcat(declar_expr[declar_expr_pointer]," F\n");
							declar_expr_pointer++;
							declar_buffer[declar_pointer]=2;
							declar_pointer++;
						}
						if(declar_type==FLOAT_t&&$5->pType->type==FLOAT_t)
						{
							fprintf(fout,".field public static %s F\n",$3);
							strcpy(declar_expr[declar_expr_pointer],"\tputstatic ");
							strcat(declar_expr[declar_expr_pointer],"output");
							strcat(declar_expr[declar_expr_pointer],"/"); 
							strcat(declar_expr[declar_expr_pointer],$3);
							strcat(declar_expr[declar_expr_pointer]," F\n");
							declar_expr_pointer++;
							declar_buffer[declar_pointer]=1;
							declar_pointer++;
						}
						if(declar_type==INTEGER_t&&$5->pType->type==INTEGER_t)
						{
							fprintf(fout,".field public static %s I\n",$3);
							strcpy(declar_expr[declar_expr_pointer],"\tputstatic ");
							strcat(declar_expr[declar_expr_pointer],"output");
							strcat(declar_expr[declar_expr_pointer],"/"); 
							strcat(declar_expr[declar_expr_pointer],$3);
							strcat(declar_expr[declar_expr_pointer]," I\n");
							declar_expr_pointer++;
							declar_buffer[declar_pointer]=1;
							declar_pointer++;
						}
						if(declar_type==BOOLEAN_t)
						{
							fprintf(fout,".field public static %s Z\n",$3);
							strcpy(declar_expr[declar_expr_pointer],"\tputstatic ");
							strcat(declar_expr[declar_expr_pointer],"output");
							strcat(declar_expr[declar_expr_pointer],"/"); 
							strcat(declar_expr[declar_expr_pointer],$3);
							strcat(declar_expr[declar_expr_pointer]," B\n");
							declar_expr_pointer++;
							declar_buffer[declar_pointer]=1;
							declar_pointer++;
						}
					}
					else
					{
						if((declar_type==DOUBLE_t||declar_type==FLOAT_t)&&$5->pType->type==INTEGER_t)
						{
							strcpy(declar_expr[declar_expr_pointer],"\ti2f\n");
							declar_expr_pointer++;
							strcpy(declar_expr[declar_expr_pointer],"\tfstore ");
							strcat(declar_expr[declar_expr_pointer],qqq);
							strcat(declar_expr[declar_expr_pointer],"\n");
							declar_expr_pointer++;
							declar_buffer[declar_pointer]=2;
							declar_pointer++;
						}
						if((declar_type==INTEGER_t||declar_type==BOOLEAN_t)&&($5->pType->type==BOOLEAN_t||$5->pType->type==INTEGER_t))
						{
							strcpy(declar_expr[declar_expr_pointer],"\tistore ");
							strcat(declar_expr[declar_expr_pointer],qqq);
							strcat(declar_expr[declar_expr_pointer],"\n");
							declar_expr_pointer++;
							declar_buffer[declar_pointer]=1;
							declar_pointer++;
						}
						if((declar_type==DOUBLE_t&&$5->pType->type==FLOAT_t)||(declar_type==DOUBLE_t&&$5->pType->type==DOUBLE_t)||(declar_type==FLOAT_t&&$5->pType->type==FLOAT_t))
						{
							strcpy(declar_expr[declar_expr_pointer],"\tfstore ");
							strcat(declar_expr[declar_expr_pointer],qqq);
							strcat(declar_expr[declar_expr_pointer],"\n");
							declar_expr_pointer++;
							declar_buffer[declar_pointer]=1;
							declar_pointer++;
						}
					}
					tem_count_stack++;					
				}
                | ID ASSIGN_OP logical_expression
				{
					char qqq[100];
					int tmp;
					int i=1;
					int count=0;
					int count2=0;
					while(tem_count_stack>=i)
					{
						i*=10;
						count2++;
					}
					i/=10;
					tmp=tem_count_stack;
					while(i!=0&&tmp!=0)
					{
						qqq[count]=tmp/i+'0';
						tmp=tmp%i;
						i=i/10;
						count++;
					}
					if(count!=count2)
					{
						int tmp2=count;
						for(int i=0;i<count2-count;i++)
						{
							qqq[tmp2]=0+'0';
							tmp2++;
						}
						qqq[tmp2]='\0';
					}
					else
					{
						qqq[count]='\0';
					}
					struct param_sem *ptr;					
					ptr = createParam( createIdList( $1 ), createPType( VOID_t ) );
					$$ = createVarDeclParam( ptr, $3 );		
					$$->isInit = __TRUE;
					if(scope==0)
					{
						if(declar_type==DOUBLE_t&&($3->pType->type==FLOAT_t)||$3->pType->type==DOUBLE_t)
						{
							fprintf(fout,".field public static %s D\n",$1);
							strcpy(declar_expr[declar_expr_pointer],"\tputstatic ");
							strcat(declar_expr[declar_expr_pointer],"output");
							strcat(declar_expr[declar_expr_pointer],"/"); 
							strcat(declar_expr[declar_expr_pointer],$1);
							strcat(declar_expr[declar_expr_pointer]," D\n");
							declar_expr_pointer++;
							declar_buffer[declar_pointer]=1;
							declar_pointer++;
						}
						if((declar_type==FLOAT_t||declar_type==DOUBLE_t)&&$3->pType->type==INTEGER_t)
						{
							fprintf(fout,".field public static %s F\n",$1);
							strcpy(declar_expr[declar_expr_pointer],"\ti2f\n");
							declar_expr_pointer++;
							strcpy(declar_expr[declar_expr_pointer],"\tputstatic ");
							strcat(declar_expr[declar_expr_pointer],"output");
							strcat(declar_expr[declar_expr_pointer],"/"); 
							strcat(declar_expr[declar_expr_pointer],$1);
							strcat(declar_expr[declar_expr_pointer]," F\n");
							declar_expr_pointer++;
							declar_buffer[declar_pointer]=2;
							declar_pointer++;
						}
						if(declar_type==FLOAT_t&&$3->pType->type==FLOAT_t)
						{
							fprintf(fout,".field public static %s F\n",$1);
							strcpy(declar_expr[declar_expr_pointer],"\tputstatic ");
							strcat(declar_expr[declar_expr_pointer],"output");
							strcat(declar_expr[declar_expr_pointer],"/"); 
							strcat(declar_expr[declar_expr_pointer],$1);
							strcat(declar_expr[declar_expr_pointer]," F\n");
							declar_expr_pointer++;
							declar_buffer[declar_pointer]=1;
							declar_pointer++;
						}
						if(declar_type==INTEGER_t&&$3->pType->type==INTEGER_t)
						{
							fprintf(fout,".field public static %s I\n",$1);
							strcpy(declar_expr[declar_expr_pointer],"\tputstatic ");
							strcat(declar_expr[declar_expr_pointer],"output");
							strcat(declar_expr[declar_expr_pointer],"/"); 
							strcat(declar_expr[declar_expr_pointer],$1);
							strcat(declar_expr[declar_expr_pointer]," I\n");
							declar_expr_pointer++;
							declar_buffer[declar_pointer]=1;
							declar_pointer++;
						}
						if(declar_type==BOOLEAN_t)
						{
							fprintf(fout,".field public static %s Z\n",$1);
							strcpy(declar_expr[declar_expr_pointer],"\tputstatic ");
							strcat(declar_expr[declar_expr_pointer],"output");
							strcat(declar_expr[declar_expr_pointer],"/"); 
							strcat(declar_expr[declar_expr_pointer],$1);
							strcat(declar_expr[declar_expr_pointer]," B\n");
							declar_expr_pointer++;
							declar_buffer[declar_pointer]=1;
							declar_pointer++;
						}
					}
					else
					{
						if((declar_type==DOUBLE_t||declar_type==FLOAT_t)&&$3->pType->type==INTEGER_t)
						{
					        strcpy(declar_expr[declar_expr_pointer],"\\ti2f\\n");
							declar_expr_pointer++;
							strcpy(declar_expr[declar_expr_pointer],"\tfstore ");
							strcat(declar_expr[declar_expr_pointer],qqq);
							strcat(declar_expr[declar_expr_pointer],"\n");
							declar_expr_pointer++;
							declar_buffer[declar_pointer]=2;
							declar_pointer++;
						}
						if((declar_type==INTEGER_t||declar_type==BOOLEAN_t)&&($3->pType->type==BOOLEAN_t||$3->pType->type==INTEGER_t))
						{
							strcpy(declar_expr[declar_expr_pointer],"\tistore ");
							strcat(declar_expr[declar_expr_pointer],qqq);
							strcat(declar_expr[declar_expr_pointer],"\n");
							declar_expr_pointer++;
							declar_buffer[declar_pointer]=1;
							declar_pointer++;
						}
						if((declar_type==DOUBLE_t&&$3->pType->type==FLOAT_t)||(declar_type==DOUBLE_t&&$3->pType->type==DOUBLE_t)||(declar_type==FLOAT_t&&$3->pType->type==FLOAT_t))
						{
							strcpy(declar_expr[declar_expr_pointer],"\tfstore ");
							strcat(declar_expr[declar_expr_pointer],qqq);
							strcat(declar_expr[declar_expr_pointer],"\n");
							declar_expr_pointer++;
							declar_buffer[declar_pointer]=1;
							declar_pointer++;
						}
					}
					tem_count_stack++;
				}
                | ID 
				{
					if(scope==0)
					{
						if(declar_type==DOUBLE_t)
						{
							fprintf(fout,".field public static %s D\n",$1);
							
						}
						if(declar_type==FLOAT_t)
						{
							fprintf(fout,".field public static %s F\n",$1);
							
						}
						if(declar_type==INTEGER_t)
						{
							fprintf(fout,".field public static %s I\n",$1);
							
						}
						if(declar_type==BOOLEAN_t)
						{
							fprintf(fout,".field public static %s Z\n",$1);
							
						}
					}
					
					struct param_sem *ptr;					
					ptr = createParam( createIdList( $1 ), createPType( VOID_t ) );
					$$ = createVarDeclParam( ptr, 0 );
					declar_buffer[declar_pointer]=0;
					declar_pointer++;
					tem_count_stack++;				
				}
                ;
		 
const_decl 	: CONST scalar_type const_list SEMICOLON
			{
				struct SymNode *newNode;				
				struct constParam *ptr;
				for( ptr=$3; ptr!=0; ptr=(ptr->next) ){
					if( verifyRedeclaration( symbolTable, ptr->name, scope ) == __TRUE ){//no redeclare
						if( ptr->value->category != $2->type ){//type different
							if( !(($2->type==FLOAT_t || $2->type == DOUBLE_t ) && ptr->value->category==INTEGER_t) ) {
								if(!($2->type==DOUBLE_t && ptr->value->category==FLOAT_t)){	
									fprintf( stdout, "########## Error at Line#%d: const type different!! ##########\n", linenum );
									semError = __TRUE;	
								}
								else{
									newNode = createConstNode( ptr->name, scope, $2, ptr->value );
									insertTab( symbolTable, newNode ,0);
								}
							}							
							else{
								newNode = createConstNode( ptr->name, scope, $2, ptr->value );
								insertTab( symbolTable, newNode ,0);
							}
						}
						else{
							newNode = createConstNode( ptr->name, scope, $2, ptr->value );
							insertTab( symbolTable, newNode ,0);
						}
					}
				}
			}
			;

const_list : const_list COMMA ID ASSIGN_OP literal_const
			{				
				addConstParam( $1, createConstParam( $5, $3 ) );
				$$ = $1;
			}
		   | ID ASSIGN_OP literal_const
			{
				$$ = createConstParam( $3, $1 );	
			}
		   ;

compound_statement : {scope++;}L_BRACE var_const_stmt_list R_BRACE
					{ 
						// print contents of current scope
						if( Opt_Symbol == 1 )
							printSymTable( symbolTable, scope );
							
						deleteScope( symbolTable, scope );	// leave this scope, delete...
						scope--; 
					}
				   ;

var_const_stmt_list : var_const_stmt_list statement	
				    | var_const_stmt_list var_decl
					| var_const_stmt_list const_decl
				    |
				    ;

statement : compound_statement
		  | simple_statement
		  | conditional_statement
		  | while_statement
		  | for_statement
		  | function_invoke_statement
		  | jump_statement
		  ;		

simple_statement : variable_reference ASSIGN_OP logical_expression SEMICOLON
					{
						struct SymNode *node;	
						node=lookupSymbol(symbolTable,$1->varRef->id,scope,__FALSE);
						if(node->scope==0)
						{
							if(node->type->type==DOUBLE_t&&($3->pType->type==FLOAT_t)||$3->pType->type==DOUBLE_t)
							{
								fprintf(fout,"\tputstatic output/%s D\n",node->name);
							}
							if((node->type->type==FLOAT_t||node->type->type==DOUBLE_t)&&$3->pType->type==INTEGER_t)
							{
								fprintf(fout,"\ti2f\n");
								fprintf(fout,"\tputstatic output/%s F\n",node->name);
							}
							if(node->type->type==FLOAT_t&&$3->pType->type==FLOAT_t)
							{
								fprintf(fout,"\tputstatic output/%s F\n",node->name);
							}
							if(node->type->type==INTEGER_t&&$3->pType->type==INTEGER_t)
							{
								fprintf(fout,"\tputstatic output/%s I\n",node->name);
							}
							if(node->type->type==BOOLEAN_t)
							{
								fprintf(fout,"\tputstatic output/%s B\n",node->name);
							}
						}
						else
						{
							if((node->type->type==DOUBLE_t||node->type->type==FLOAT_t)&&$3->pType->type==INTEGER_t)
							{
								fprintf(fout,"\ti2f\n");
								fprintf(fout,"\tfstore %d\n",node->local_num);
							}
							if((node->type->type==INTEGER_t||node->type->type==BOOLEAN_t)&&($3->pType->type==BOOLEAN_t||$3->pType->type==INTEGER_t))
							{
								fprintf(fout,"\tistore %d\n",node->local_num);
							}
							if((node->type->type==DOUBLE_t&&$3->pType->type==FLOAT_t)||(node->type->type==DOUBLE_t&&$3->pType->type==DOUBLE_t)||(node->type->type==FLOAT_t&&$3->pType->type==FLOAT_t))
							{
								fprintf(fout,"\tfstore %d\n",node->local_num);
							}
						}
						// check if LHS exists
						__BOOLEAN flagLHS = verifyExistence( symbolTable, $1, scope, __TRUE );
						// id RHS is not dereferenced, check and deference
						__BOOLEAN flagRHS = __TRUE;
						if( $3->isDeref == __FALSE ) {
							flagRHS = verifyExistence( symbolTable, $3, scope, __FALSE );
						}
						// if both LHS and RHS are exists, verify their type
						if( flagLHS==__TRUE && flagRHS==__TRUE )
							verifyAssignmentTypeMatch( $1, $3 );

						
						
					}
				 | PRINT{fprintf(fout,"\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n"); } 
				 	logical_expression SEMICOLON 
				 	{ 
				 		verifyScalarExpr( $3, "print" ); 
				 		if($3->pType->type==INTEGER_t)
				 		{
				 			fprintf(fout, "\tinvokevirtual java/io/PrintStream/print(I)V\n");
				 		}
						else if($3->pType->type==FLOAT_t)
						{
							fprintf(fout, "\tinvokevirtual java/io/PrintStream/print(F)V\n");
						}
						else if($3->pType->type==DOUBLE_t)
						{
							fprintf(fout, "\tinvokevirtual java/io/PrintStream/print(D)V\n");
						}
						else if($3->pType->type==BOOLEAN_t)
						{
							fprintf(fout, "\tinvokevirtual java/io/PrintStream/print(Z)V\n");
						}
						else if($3->pType->type==STRING_t)
						{
							fprintf(fout, "\tinvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n");
						}
				 	}
				 | READ variable_reference SEMICOLON 
					{ 
						if( verifyExistence( symbolTable, $2, scope, __TRUE ) == __TRUE )						
							verifyScalarExpr( $2, "read" );
						struct SymNode *node;	
						node=lookupSymbol(symbolTable,$2->varRef->id,scope,__FALSE);
						fprintf(fout,"\tgetstatic output/_sc Ljava/util/Scanner;\n");					
						if(node->category==VARIABLE_t||node->category==PARAMETER_t)
						{
							if(node->scope==0)
							{
								if(node->type->type==DOUBLE_t)
								{
									fprintf(fout,"\tinvokevirtual java/util/Scanner/nextDouble()D\n");
									fprintf(fout,"\tputstatic output/%s D \n",node->name);
								}
								if(node->type->type==FLOAT_t)
								{
									fprintf(fout,"\tinvokevirtual java/util/Scanner/nextFloat()F\n");
									fprintf(fout,"\tputstatic output/%s F \n",node->name);
								}
								if(node->type->type==INTEGER_t)
								{
									fprintf(fout,"\tinvokevirtual java/util/Scanner/nextInt()I\n");
									fprintf(fout,"\tputstatic output/%s I \n",node->name);
								}
								if(node->type->type==BOOLEAN_t)
								{
									fprintf(fout,"\tinvokevirtual java/util/Scanner/nextBoolean()Z\n");
									fprintf(fout,"\tputstatic output/%s Z \n",node->name);
								}
							}
							else
							{
								if(node->type->type==DOUBLE_t)
								{
									fprintf(fout,"\tinvokevirtual java/util/Scanner/nextDouble()D\n");
									fprintf(fout,"\tfstore %d\n",node->local_num);
								}
								if(node->type->type==FLOAT_t)
								{
									fprintf(fout,"\tinvokevirtual java/util/Scanner/nextFloat()F\n");
									fprintf(fout,"\tfstore %d\n",node->local_num);
								}
								if(node->type->type==INTEGER_t)
								{
									fprintf(fout,"\tinvokevirtual java/util/Scanner/nextInt()I\n");
									fprintf(fout,"\tistore %d\n",node->local_num);
								}
								if(node->type->type==BOOLEAN_t)
								{
									fprintf(fout,"\tinvokevirtual java/util/Scanner/nextBoolean()Z\n");
									fprintf(fout,"\tistore %d\n",node->local_num);
								}
							}
						}
						else if(node->category==CONSTANT_t)
						{
							if(node->attribute->constVal->category==DOUBLE_t)
							{
								fprintf(fout,"\tldc %f\n",node->attribute->constVal->value.doubleVal);
							}
							if(node->attribute->constVal->category==INTEGER_t)
							{
								fprintf(fout,"\tldc %d\n",node->attribute->constVal->value.integerVal);
							}
							if(node->attribute->constVal->category==FLOAT_t)
							{
								fprintf(fout,"\tldc %f\n",node->attribute->constVal->value.floatVal);
							}
							if(node->attribute->constVal->category==BOOLEAN_t)
							{
								if(node->attribute->constVal->value.booleanVal==__TRUE)
								{
									fprintf(fout,"\ticonst_1\n");
								}
								if(node->attribute->constVal->value.booleanVal==__FALSE)
								{
									fprintf(fout,"\ticonst_0\n");
								}					
							}
							if(node->attribute->constVal->category==STRING_t)
							{
								int i;
							  	fprintf(fout,"\tldc \"");
							  	for(i=0;i<strlen(node->attribute->constVal->value.stringVal);i++)
							  	{
							  		if(node->attribute->constVal->value.stringVal[i]=='\n')
							  		{
							  			fprintf(fout,"\\n");
							  		}
							  		else
							  		{
							  			fprintf(fout,"%c",node->attribute->constVal->value.stringVal[i]);
							  		}
							  		
							  	}
							  	fprintf(fout,"\"\n");
							}
						}
					}
				 ;

conditional_statement : ifstatment compound_statement
						{
							fprintf(fout, "\tgoto Lexit_%d\n", index_buffer[pointer-1]);
							fprintf(fout, "Lelse_%d:\n", index_buffer[pointer-1]);
							fprintf(fout, "Lexit_%d:\n", index_buffer[pointer-1]);
							pointer--;
						}
					  | ifstatment compound_statement
						ELSE 
						{
							fprintf(fout, "\tgoto Lexit_%d\n",index_buffer[pointer-1]);
							fprintf(fout, "Lelse_%d:\n", index_buffer[pointer-1]);
						}
						compound_statement
						{
							fprintf(fout, "Lexit_%d:\n", index_buffer[pointer-1]);
							pointer--;
						}
					  ;
ifstatment : IF L_PAREN conditional_if R_PAREN
			 {
				index_buffer[pointer]=if_for_while_index;
				fprintf(fout,"\tifeq Lelse_%d\n",index_buffer[pointer]);
				pointer++;
				if_for_while_index++;
			 }
			 ;

conditional_if : logical_expression { verifyBooleanExpr( $1, "if" ); };					  

				
while_statement : WHILE 
				  {
				  	index_buffer[pointer]=if_for_while_index;
					fprintf(fout,"Lbegin_%d:\n",index_buffer[pointer]);
					pointer++;
					if_for_while_index++;
				  }	
				  L_PAREN logical_expression { verifyBooleanExpr( $4, "while" ); } 
				  R_PAREN 
				  { 
				  	inloop++;
				  	fprintf(fout,"\tifeq Lexit_%d\n",index_buffer[pointer-1]);
				  }
				  compound_statement 
				  { 
				  	inloop--;
				  	fprintf(fout, "\tgoto Lbegin_%d\n", index_buffer[pointer-1]);
					fprintf(fout, "Lexit_%d:\n", index_buffer[pointer-1]);
					pointer--;
				  }
				| { inloop++; } 
				  DO 
				  {
				  	index_buffer[pointer]=if_for_while_index;
					fprintf(fout,"Lbegin_%d:\n",index_buffer[pointer]);
					pointer++;
					if_for_while_index++;
				  }
				  compound_statement WHILE L_PAREN logical_expression R_PAREN
				  {
				  	fprintf(fout,"\tifeq Lexit_%d\n",index_buffer[pointer-1]);
				  	fprintf(fout, "\tgoto Lbegin_%d\n", index_buffer[pointer-1]);
					fprintf(fout, "Lexit_%d:\n", index_buffer[pointer-1]);
					pointer--;
				  } 
				  SEMICOLON  
					{ 
						 verifyBooleanExpr( $7, "while" );
						 inloop--; 
						
					}
				;


				
for_statement : FOR 
				{
					index_buffer[pointer]=if_for_while_index;
					pointer++;
					if_for_while_index++;
				}
				L_PAREN initial_expression SEMICOLON control_expression SEMICOLON increment_expression R_PAREN  
				{ 
					inloop++;
					fprintf(fout, "Lexec_%d:\n", index_buffer[pointer-1]);
				}
				compound_statement  
				{ 
					inloop--;
					fprintf(fout, "\tgoto Lincre_%d\n",index_buffer[pointer-1]);
					fprintf(fout, "Lexit_%d:\n", index_buffer[pointer-1]);
					pointer--; 
				}
			  ;

initial_expression : initial_expression COMMA statement_for	{fprintf(fout,"Lbegin_%d:\n",index_buffer[pointer-1]);}	
				   | initial_expression COMMA logical_expression {fprintf(fout,"Lbegin_%d:\n",index_buffer[pointer-1]);}	
				   | logical_expression	 {fprintf(fout,"Lbegin_%d:\n",index_buffer[pointer-1]);}	
				   | statement_for {fprintf(fout,"Lbegin_%d:\n",index_buffer[pointer-1]);}	
				   | {fprintf(fout,"Lbegin_%d:\n",index_buffer[pointer-1]);}	
				   ;

control_expression : control_expression COMMA statement_for
				   {
				   		fprintf(fout, "\tifeq Lexit_%d\n", index_buffer[pointer-1]);
						fprintf(fout, "\tgoto Lexec_%d\n", index_buffer[pointer-1]);
						fprintf(fout, "Lincre_%d:\n", index_buffer[pointer-1]);
						fprintf( stdout, "########## Error at Line#%d: control_expression is not boolean type ##########\n", linenum );
						semError = __TRUE;	
				   }
				   | control_expression COMMA logical_expression
				   {
				   		fprintf(fout, "\tifeq Lexit_%d\n", index_buffer[pointer-1]);
						fprintf(fout, "\tgoto Lexec_%d\n", index_buffer[pointer-1]);
						fprintf(fout, "Lincre_%d:\n", index_buffer[pointer-1]);
						if( $3->pType->type != BOOLEAN_t ){
							fprintf( stdout, "########## Error at Line#%d: control_expression is not boolean type ##########\n", linenum );
							semError = __TRUE;	
						}
				   }
				   | logical_expression 
					{ 
						fprintf(fout, "\tifeq Lexit_%d\n", index_buffer[pointer-1]);
						fprintf(fout, "\tgoto Lexec_%d\n", index_buffer[pointer-1]);
						fprintf(fout, "Lincre_%d:\n", index_buffer[pointer-1]);
						if( $1->pType->type != BOOLEAN_t ){
							fprintf( stdout, "########## Error at Line#%d: control_expression is not boolean type ##########\n", linenum );
							semError = __TRUE;	
						}
					}
				   | statement_for
				   {
				   		fprintf(fout, "\tifeq Lexit_%d\n", index_buffer[pointer-1]);
						fprintf(fout, "\tgoto Lexec_%d\n", index_buffer[pointer-1]);
						fprintf(fout, "Lincre_%d:\n", index_buffer[pointer-1]);
						fprintf( stdout, "########## Error at Line#%d: control_expression is not boolean type ##########\n", linenum );
						semError = __TRUE;	
				   }
				   | {fprintf(fout, "\tifeq Lexit_%d\n", index_buffer[pointer-1]);
						fprintf(fout, "\tgoto Lexec_%d\n", index_buffer[pointer-1]);
						fprintf(fout, "Lincre_%d:\n", index_buffer[pointer-1]);}
				   ;

increment_expression : increment_expression COMMA statement_for {fprintf(fout, "\tgoto Lbegin_%d\n", index_buffer[pointer-1]);}
					 | increment_expression COMMA logical_expression {fprintf(fout, "\tgoto Lbegin_%d\n", index_buffer[pointer-1]);}
					 | logical_expression {fprintf(fout, "\tgoto Lbegin_%d\n", index_buffer[pointer-1]);}
					 | statement_for {fprintf(fout, "\tgoto Lbegin_%d\n", index_buffer[pointer-1]);}
					 | {fprintf(fout, "\tgoto Lbegin_%d\n", index_buffer[pointer-1]);}
					 ;

statement_for 	: variable_reference ASSIGN_OP logical_expression
					{
						struct SymNode *node;	
						node=lookupSymbol(symbolTable,$1->varRef->id,scope,__FALSE);
						if(node->scope==0)
						{
							if(node->type->type==DOUBLE_t&&($3->pType->type==FLOAT_t)||$3->pType->type==DOUBLE_t)
							{
								fprintf(fout,"\tputstatic output/%s D\n",node->name);
							}
							if((node->type->type==FLOAT_t||node->type->type==DOUBLE_t)&&$3->pType->type==INTEGER_t)
							{
								fprintf(fout,"\ti2f\n");
								fprintf(fout,"\tputstatic output/%s F\n",node->name);
							}
							if(node->type->type==FLOAT_t&&$3->pType->type==FLOAT_t)
							{
								fprintf(fout,"\tputstatic output/%s F\n",node->name);
							}
							if(node->type->type==INTEGER_t&&$3->pType->type==INTEGER_t)
							{
								fprintf(fout,"\tputstatic output/%s I\n",node->name);
							}
							if(node->type->type==BOOLEAN_t)
							{
								fprintf(fout,"\tputstatic output/%s B\n",node->name);
							}
						}
						else
						{
							if((node->type->type==DOUBLE_t||node->type->type==FLOAT_t)&&$3->pType->type==INTEGER_t)
							{
								fprintf(fout,"\ti2f\n");
								fprintf(fout,"\tfstore %d\n",node->local_num);
							}
							if((node->type->type==INTEGER_t||node->type->type==BOOLEAN_t)&&($3->pType->type==BOOLEAN_t||$3->pType->type==INTEGER_t))
							{
								fprintf(fout,"\tistore %d\n",node->local_num);
							}
							if((node->type->type==DOUBLE_t&&$3->pType->type==FLOAT_t)||(node->type->type==DOUBLE_t&&$3->pType->type==DOUBLE_t)||(node->type->type==FLOAT_t&&$3->pType->type==FLOAT_t))
							{
								fprintf(fout,"\tfstore %d\n",node->local_num);
							}
						}
						
			
			
						// check if LHS exists
						__BOOLEAN flagLHS = verifyExistence( symbolTable, $1, scope, __TRUE );
						// id RHS is not dereferenced, check and deference
						__BOOLEAN flagRHS = __TRUE;
						if( $3->isDeref == __FALSE ) {
							flagRHS = verifyExistence( symbolTable, $3, scope, __FALSE );
						}
						// if both LHS and RHS are exists, verify their type
						if( flagLHS==__TRUE && flagRHS==__TRUE )
							verifyAssignmentTypeMatch( $1, $3 );
					}
					;
					 
					 
function_invoke_statement : ID L_PAREN logical_expression_list R_PAREN SEMICOLON
							{
								verifyFuncInvoke( $1, $3, symbolTable, scope );
								struct SymNode *node;	
								node=lookupSymbol(symbolTable,$1,scope,__FALSE);
								fprintf(fout,"\tinvokestatic output/%s(",$1);
								struct PTypeList *list=node->attribute->formalParam->params;
								while(list!=0)
								{
									if(list->value->type==INTEGER_t)
									{
										fprintf(fout,"I");
									}
									if(list->value->type==BOOLEAN_t)
									{
										fprintf(fout,"B");
									}
									if(list->value->type==FLOAT_t)
									{
										fprintf(fout,"F");
									}
									if(list->value->type==DOUBLE_t)
									{
										fprintf(fout,"D");
									}
									list=list->next;
								}
								fprintf(fout,")");
								if(node->type->type==INTEGER_t)
								{
									fprintf(fout,"I\n");
								}
								if(node->type->type==BOOLEAN_t)
								{
									fprintf(fout,"B\n");
								}
								if(node->type->type==FLOAT_t)
								{
									fprintf(fout,"F\n");
								}
								if(node->type->type==DOUBLE_t)
								{
									fprintf(fout,"D\n");
								}
								if(node->type->type==VOID_t)
								{
									fprintf(fout,"V\n");
								}

							}
						  | ID L_PAREN R_PAREN SEMICOLON
							{
								verifyFuncInvoke( $1, 0, symbolTable, scope );
								struct SymNode *node;	
								node=lookupSymbol(symbolTable,$1,scope,__FALSE);
								if(node->type->type==INTEGER_t)
								{
									fprintf(fout,"\tinvokestatic output/%s()I\n",$1);
								}
								if(node->type->type==BOOLEAN_t)
								{
									fprintf(fout,"\tinvokestatic output/%s()Z\n",$1);
								}
								if(node->type->type==FLOAT_t)
								{
									fprintf(fout,"\tinvokestatic output/%s()F\n",$1);
								}
								if(node->type->type==DOUBLE_t)
								{
									fprintf(fout,"\tinvokestatic output/%s()D\n",$1);
								}
								if(node->type->type==VOID_t)
								{
									fprintf(fout,"\tinvokestatic output/%s()V\n",$1);
								}
							}
						  ;

jump_statement : CONTINUE SEMICOLON
				{
					if( inloop <= 0){
						fprintf( stdout, "########## Error at Line#%d: continue can't appear outside of loop ##########\n", linenum ); semError = __TRUE;
					}
				}
			   | BREAK SEMICOLON 
				{
					if( inloop <= 0){
						fprintf( stdout, "########## Error at Line#%d: break can't appear outside of loop ##########\n", linenum ); semError = __TRUE;
					}
				}
			   | RETURN logical_expression SEMICOLON
				{
					verifyReturnStatement( $2, funcReturn );
					if(entrypoint==1)
					{
						fprintf(fout, "\treturn\n");
						entrypoint=0;
					}
					else if($2->pType->type==INTEGER_t)
					{
						fprintf(fout, "\tireturn\n");
					}
					else if($2->pType->type==DOUBLE_t)
					{
						fprintf(fout, "\tdreturn\n");
					}
					else if($2->pType->type==FLOAT_t)
					{
						fprintf(fout, "\tfreturn\n");
					}
					else if($2->pType->type==BOOLEAN_t)
					{
						fprintf(fout, "\tireturn\n");
					}
				}
			   ;

variable_reference : ID
					{
						$$ = createExprSem( $1 );
					}
				   ;
  
logical_expression : logical_expression OR_OP logical_term
					{
						verifyAndOrOp( $1, OR_t, $3 );
						$$ = $1;
						fprintf(fout,"\tior\n");
					}
				   | logical_term { $$ = $1; }
				   ;

logical_term : logical_term AND_OP logical_factor
				{
					verifyAndOrOp( $1, AND_t, $3 );
					$$ = $1;
					fprintf(fout,"\tiand\n");
				}
			 | logical_factor { $$ = $1; }
			 ;

logical_factor : NOT_OP logical_factor
				{
					verifyUnaryNOT( $2 );
					$$ = $2;
					fprintf(fout,"\tixor\n");
				}
			   | relation_expression { $$ = $1; }
			   ;

relation_expression : arithmetic_expression relation_operator arithmetic_expression
					{
						if($1->pType->type==INTEGER_t&&$3->pType->type==INTEGER_t)
						{
							fprintf(fout, "\tisub\n");
						}
						else
						{
							fprintf(fout, "\tfcmpl\n");
						}
						if($2==LT_t)
						{
							fprintf(fout, "\tiflt ");
						}
						else if($2==LE_t)
						{
							fprintf(fout, "\tifle ");
						}
						else if($2==NE_t)
						{
							fprintf(fout, "\tifne ");
						}
						else if($2==GE_t)
						{
							fprintf(fout, "\tifge ");
						}
						else if($2==GT_t)
						{
							fprintf(fout, "\tifgt ");
						}
						else if($2==EQ_t)
						{
							fprintf(fout, "\tifeq ");
						}
						fprintf(fout, "Ltrue_%d\n", true_index);
						fprintf(fout, "\ticonst_0\n");
						fprintf(fout, "\tgoto Lfalse_%d\n", false_index);
						fprintf(fout, "Ltrue_%d:\n", true_index++);
						fprintf(fout, "\ticonst_1\n");
						fprintf(fout, "Lfalse_%d:\n", false_index++);
						verifyRelOp( $1, $2, $3 );
						$$ = $1;
						
					}
					| arithmetic_expression { $$ = $1; }
					;

relation_operator : LT_OP { $$ = LT_t; }
				  | LE_OP { $$ = LE_t; }
				  | EQ_OP { $$ = EQ_t; }
				  | GE_OP { $$ = GE_t; }
				  | GT_OP { $$ = GT_t; }
				  | NE_OP { $$ = NE_t; }
				  ;

arithmetic_expression : arithmetic_expression add_op term
			{
				if($2==ADD_t)
				{
					if($1->pType->type==INTEGER_t&&$3->pType->type==INTEGER_t)
					{
						fprintf(fout,"\tiadd\n");
					}
					else if(($1->pType->type==FLOAT_t||$1->pType->type==DOUBLE_t)&&$3->pType->type==INTEGER_t)
					{
						fprintf(fout,"\ti2f\n");
						fprintf(fout,"\tfadd\n");
					}
					else if(($3->pType->type==FLOAT_t||$3->pType->type==DOUBLE_t)&&$1->pType->type==INTEGER_t)
					{
						fprintf(fout,"\tfstore 99\n");
						fprintf(fout,"\ti2f\n");
						fprintf(fout,"\tfload 99\n");
						fprintf(fout,"\tfadd\n");
					}
					else
					{
						fprintf(fout,"\tfadd\n");
					}
				}
				if($2==SUB_t)
				{
					if($1->pType->type==INTEGER_t&&$3->pType->type==INTEGER_t)
					{
						fprintf(fout,"\tisub\n");
					}
					else if(($1->pType->type==FLOAT_t||$1->pType->type==DOUBLE_t)&&$3->pType->type==INTEGER_t)
					{
						fprintf(fout,"\ti2f\n");
						fprintf(fout,"\tfsub\n");
					}
					else if(($3->pType->type==FLOAT_t||$3->pType->type==DOUBLE_t)&&$1->pType->type==INTEGER_t)
					{
						fprintf(fout,"\tfstore 99\n");
						fprintf(fout,"\ti2f\n");
						fprintf(fout,"\tfload 99\n");
						fprintf(fout,"\tfsub\n");
					}
					else
					{
						fprintf(fout,"\tfsub\n");
					}
				}
				verifyArithmeticOp( $1, $2, $3 );
				$$ = $1;
				
			}
           | relation_expression { $$ = $1; }
		   | term { $$ = $1; }
		   ;

add_op	: ADD_OP { $$ = ADD_t; }
		| SUB_OP { $$ = SUB_t; }
		;
		   
term : term mul_op factor
		{
			if($2==MUL_t)
			{
				if($1->pType->type==INTEGER_t&&$3->pType->type==INTEGER_t)
				{
					fprintf(fout,"\timul\n");
				}
				else if(($1->pType->type==FLOAT_t||$1->pType->type==DOUBLE_t)&&$3->pType->type==INTEGER_t)
				{
					fprintf(fout,"\ti2f\n");
					fprintf(fout,"\tfmul\n");
				}
				else if(($3->pType->type==FLOAT_t||$3->pType->type==DOUBLE_t)&&$1->pType->type==INTEGER_t)
				{
					fprintf(fout,"\tfstore 99\n");
					fprintf(fout,"\ti2f\n");
					fprintf(fout,"\tfload 99\n");
					fprintf(fout,"\tfmul\n");
				}
				else
				{
					fprintf(fout,"\tfmul\n");
				}
			}
			else if($2==DIV_t)
			{
				if($1->pType->type==INTEGER_t&&$3->pType->type==INTEGER_t)
				{
					fprintf(fout,"\tidiv\n");
				}
				else if(($1->pType->type==FLOAT_t||$1->pType->type==DOUBLE_t)&&$3->pType->type==INTEGER_t)
				{
					fprintf(fout,"\ti2f\n");
					fprintf(fout,"\tfdiv\n");
				}
				else if(($3->pType->type==FLOAT_t||$3->pType->type==DOUBLE_t)&&$1->pType->type==INTEGER_t)
				{
					fprintf(fout,"\tfstore 99\n");
					fprintf(fout,"\ti2f\n");
					fprintf(fout,"\tfload 99\n");
					fprintf(fout,"\tfdiv\n");
				}
				else
				{
					fprintf(fout,"\tfdiv\n");
				}
			}
			else if($2==MOD_t)
			{
				fprintf(fout,"\tirem\n");
			}
			else if( $2 == MOD_t ) {
				verifyModOp( $1, $3 );
			}
			else {
				verifyArithmeticOp( $1, $2, $3 );
			}
			
			$$ = $1;
		}
     | factor { $$ = $1; }
	 ;

mul_op 	: MUL_OP { $$ = MUL_t; }
		| DIV_OP { $$ = DIV_t; }
		| MOD_OP { $$ = MOD_t; }
		;
		
factor : variable_reference
		{
			struct SymNode *node;	
			node=lookupSymbol(symbolTable,$1->varRef->id,scope,__FALSE);
			if(node->category==VARIABLE_t||node->category==PARAMETER_t)
			{
				if(node->scope==0)
				{
					if(node->type->type==DOUBLE_t)
					{
						fprintf(fout,"\tgetstatic output/%s D\n",node->name);
					}
					if(node->type->type==FLOAT_t)
					{
						fprintf(fout,"\tgetstatic output/%s F\n",node->name);
					}
					if(node->type->type==INTEGER_t)
					{
						fprintf(fout,"\tgetstatic output/%s I\n",node->name);
					}
					if(node->type->type==BOOLEAN_t)
					{
						fprintf(fout,"\tgetstatic output/%s Z\n",node->name);
					}
				}
				else
				{
					if(node->type->type==DOUBLE_t||node->type->type==FLOAT_t)
					{
						fprintf(fout,"\tfload %d\n",node->local_num);
					}
					if(node->type->type==INTEGER_t||node->type->type==BOOLEAN_t)
					{
						fprintf(fout,"\tiload %d\n",node->local_num);
					}
				}
			}
			else if(node->category==CONSTANT_t)
			{
				if(node->attribute->constVal->category==DOUBLE_t)
				{
					fprintf(fout,"\tldc %f\n",node->attribute->constVal->value.doubleVal);
				}
				if(node->attribute->constVal->category==INTEGER_t)
				{
					fprintf(fout,"\tldc %d\n",node->attribute->constVal->value.integerVal);
				}
				if(node->attribute->constVal->category==FLOAT_t)
				{
					fprintf(fout,"\tldc %f\n",node->attribute->constVal->value.floatVal);
				}
				if(node->attribute->constVal->category==BOOLEAN_t)
				{
					if(node->attribute->constVal->value.booleanVal==__TRUE)
					{
						fprintf(fout,"\ticonst_1\n");
					}
					if(node->attribute->constVal->value.booleanVal==__FALSE)
					{
						fprintf(fout,"\ticonst_0\n");
					}					
				}
				if(node->attribute->constVal->category==STRING_t)
				{
					int i;
				  	fprintf(fout,"\tldc \"");
				  	for(i=0;i<strlen(node->attribute->constVal->value.stringVal);i++)
				  	{
				  		if(node->attribute->constVal->value.stringVal[i]=='\n')
				  		{
				  			fprintf(fout,"\\n");
				  		}
				  		else
				  		{
				  			fprintf(fout,"%c",node->attribute->constVal->value.stringVal[i]);
				  		}
				  		
				  	}
				  	fprintf(fout,"\"\n");
				}
			}
			verifyExistence( symbolTable, $1, scope, __FALSE );
			$$ = $1;
			$$->beginningOp = NONE_t;

		}
	   | SUB_OP variable_reference
		{
			if( verifyExistence( symbolTable, $2, scope, __FALSE ) == __TRUE )
				verifyUnaryMinus( $2 );
			struct SymNode *node;	
			node=lookupSymbol(symbolTable,$2->varRef->id,scope,__FALSE);
			if(node->category==VARIABLE_t||node->category==PARAMETER_t)
			{
				if(node->scope==0)
				{
					if(node->type->type==DOUBLE_t)
					{
						fprintf(fout,"\tgetstatic output/%s D\n",node->name);
						fprintf(fout,"\tfneg\n");
					}
					if(node->type->type==FLOAT_t)
					{
						fprintf(fout,"\tgetstatic output/%s F\n",node->name);
						fprintf(fout,"\tfneg\n");
					}
					if(node->type->type==INTEGER_t)
					{
						fprintf(fout,"\tgetstatic output/%s I\n",node->name);
						fprintf(fout,"\tineg\n");
					}
				}
				else
				{
					if(node->type->type==DOUBLE_t||node->type->type==FLOAT_t)
					{
						fprintf(fout,"\tfload %d\n",node->local_num);
						fprintf(fout,"\tfneg\n");
					}
					if(node->type->type==INTEGER_t)
					{
						fprintf(fout,"\tiload %d\n",node->local_num);
						fprintf(fout,"\tineg\n");
					}
				}
			}
			else if(node->category==CONSTANT_t)
			{
				if(node->attribute->constVal->category==DOUBLE_t)
				{
					fprintf(fout,"\tldc %f\n",node->attribute->constVal->value.doubleVal);
					fprintf(fout,"\tfneg\n");
				}
				if(node->attribute->constVal->category==INTEGER_t)
				{
					fprintf(fout,"\tldc %d\n",node->attribute->constVal->value.integerVal);
					fprintf(fout,"\tineg\n");
				}
				if(node->attribute->constVal->category==FLOAT_t)
				{
					fprintf(fout,"\tldc %f\n",node->attribute->constVal->value.floatVal);
					fprintf(fout,"\tfneg\n");
				}
			}
			$$ = $2;
			$$->beginningOp = SUB_t;
		}		
	   | L_PAREN logical_expression R_PAREN
		{
			$2->beginningOp = NONE_t;
			$$ = $2; 
		}
	   | SUB_OP L_PAREN logical_expression R_PAREN
		{
			verifyUnaryMinus( $3 );
			$$ = $3;
			$$->beginningOp = SUB_t;
			if($3->pType->type==INTEGER_t)
			{
				fprintf(fout,"ineg\n");
			}
			if($3->pType->type==FLOAT_t)
			{
				fprintf(fout,"fneg\n");
			}
			if($3->pType->type==DOUBLE_t)
			{
				fprintf(fout,"fneg\n");
			}
		}
	   | ID L_PAREN logical_expression_list R_PAREN
		{
			$$ = verifyFuncInvoke( $1, $3, symbolTable, scope );
			$$->beginningOp = NONE_t;
			struct SymNode *node;	
			node=lookupSymbol(symbolTable,$1,scope,__FALSE);
			fprintf(fout,"\tinvokestatic output/%s(",$1);
			struct PTypeList *list=node->attribute->formalParam->params;
			while(list!=0)
			{
				if(list->value->type==INTEGER_t)
				{
					fprintf(fout,"I");
				}
				if(list->value->type==BOOLEAN_t)
				{
					fprintf(fout,"B");
				}
				if(list->value->type==FLOAT_t)
				{
					fprintf(fout,"F");
				}
				if(list->value->type==DOUBLE_t)
				{
					fprintf(fout,"D");
				}
				list=list->next;
			}
			fprintf(fout,")");
			if(node->type->type==INTEGER_t)
			{
				fprintf(fout,"I\n");
			}
			if(node->type->type==BOOLEAN_t)
			{
				fprintf(fout,"B\n");
			}
			if(node->type->type==FLOAT_t)
			{
				fprintf(fout,"F\n");
			}
			if(node->type->type==DOUBLE_t)
			{
				fprintf(fout,"D\n");
			}
			if(node->type->type==VOID_t)
			{
				fprintf(fout,"V\n");
			}
		}
	   | SUB_OP ID L_PAREN logical_expression_list R_PAREN
	    {
			$$ = verifyFuncInvoke( $2, $4, symbolTable, scope );
			$$->beginningOp = SUB_t;
			struct SymNode *node;	
			node=lookupSymbol(symbolTable,$2,scope,__FALSE);
			fprintf(fout,"\tinvokestatic output/%s(",$2);
			struct PTypeList *list=node->attribute->formalParam->params;
			while(list!=0)
			{
				if(list->value->type==INTEGER_t)
				{
					fprintf(fout,"I");
				}
				if(list->value->type==BOOLEAN_t)
				{
					fprintf(fout,"B");
				}
				if(list->value->type==FLOAT_t)
				{
					fprintf(fout,"F");
				}
				if(list->value->type==DOUBLE_t)
				{
					fprintf(fout,"D");
				}
				list=list->next;
			}
			fprintf(fout,")");
			if(node->type->type==INTEGER_t)
			{
				fprintf(fout,"I\n");
				fprintf(fout,"ineg\n");
			}
			if(node->type->type==FLOAT_t)
			{
				fprintf(fout,"F\n");
				fprintf(fout,"fneg\n");
			}
			if(node->type->type==DOUBLE_t)
			{
				fprintf(fout,"D\n");
				fprintf(fout,"fneg\n");
			}
		}
	   | ID L_PAREN R_PAREN
		{
			$$ = verifyFuncInvoke( $1, 0, symbolTable, scope );
			$$->beginningOp = NONE_t;
			struct expr_sem *node;
			node=verifyFuncInvoke( $1, 0, symbolTable, scope );
			fprintf(fout,"\tinvokestatic output/%s()",$1);
			if(node->pType->type==INTEGER_t)
			{
				fprintf(fout,"I\n");
			}
			if(node->pType->type==BOOLEAN_t)
			{
				fprintf(fout,"Z\n");
			}
			if(node->pType->type==DOUBLE_t)
			{
				fprintf(fout,"D\n");
			}
			if(node->pType->type==VOID_t)
			{
				fprintf(fout,"V\n");
			}
			if(node->pType->type==FLOAT_t)
			{
				fprintf(fout,"F\n");
			}
		}
	   | SUB_OP ID L_PAREN R_PAREN
		{
			$$ = verifyFuncInvoke( $2, 0, symbolTable, scope );
			$$->beginningOp = SUB_OP;
			struct expr_sem *node;
			node=verifyFuncInvoke( $2, 0, symbolTable, scope );
			fprintf(fout,"\tinvokestatic output/%s()",$2);
			if(node->pType->type==INTEGER_t)
			{
				fprintf(fout,"I\n");
				fprintf(fout,"ineg\n");
			}
			if(node->pType->type==DOUBLE_t)
			{
				fprintf(fout,"D\n");
				fprintf(fout,"fneg\n");
			}
			if(node->pType->type==FLOAT_t)
			{
				fprintf(fout,"F\n");
				fprintf(fout,"fneg\n");
			}
		}
	   | literal_const
	    {

			  $$ = (struct expr_sem *)malloc(sizeof(struct expr_sem));
			  $$->isDeref = __TRUE;
			  $$->varRef = 0;
			  $$->pType = createPType( $1->category );
			  $$->next = 0;
			  if( $1->hasMinus == __TRUE ) {
			  	$$->beginningOp = SUB_t;
			  }
			  else {
				$$->beginningOp = NONE_t;
			  }
			  if($1->category==INTEGER_t)
			  {
			  	fprintf(fout,"\tldc %d\n",$1->value.integerVal);
			  }
			  if($1->category==STRING_t)
			  {
			  	int i;
			  	fprintf(fout,"\tldc \"");
			  	for(i=0;i<strlen($1->value.stringVal);i++)
			  	{
			  		if($1->value.stringVal[i]=='\n')
			  		{
			  			fprintf(fout,"\\n");
			  		}
			  		else
			  		{
			  			fprintf(fout,"%c",$1->value.stringVal[i]);
			  		}
			  		
			  	}
			  	fprintf(fout,"\"\n");			  	
			  }
			  if($1->category==FLOAT_t)
			  {
			  	fprintf(fout,"\tldc %f\n",$1->value.floatVal);
			  }
			  if($1->category==DOUBLE_t)
			  {
			  	fprintf(fout,"\tldc %f\n",$1->value.doubleVal);
			  }
			  if($1->category==BOOLEAN_t)
			  {
			  	if($1->value.booleanVal==__TRUE)
			  	{
			  		fprintf(fout, "\ticonst_1\n");
			  	}
			  	else
			  	{
			  		fprintf(fout, "\ticonst_0\n");
			  	}
			  }
		}
	   ;

logical_expression_list : logical_expression_list COMMA logical_expression
						{
			  				struct expr_sem *exprPtr;
			  				for( exprPtr=$1 ; (exprPtr->next)!=0 ; exprPtr=(exprPtr->next) );
			  				exprPtr->next = $3;
			  				$$ = $1;
						}
						| logical_expression { $$ = $1; }
						;

		  


scalar_type : INT {tem_count_stack=count_stack; declar_type=INTEGER_t; $$ = createPType( INTEGER_t ); }
			| DOUBLE {tem_count_stack=count_stack; declar_type=DOUBLE_t;$$ = createPType( DOUBLE_t ); }
			| STRING {tem_count_stack=count_stack; declar_type=STRING_t;$$ = createPType( STRING_t ); }
			| BOOL {tem_count_stack=count_stack; declar_type=BOOLEAN_t;$$ = createPType( BOOLEAN_t ); }
			| FLOAT { tem_count_stack=count_stack;declar_type=FLOAT_t;$$ = createPType( FLOAT_t ); }
			;
 
literal_const : INT_CONST
				{
					int tmp = $1;
					$$ = createConstAttr( INTEGER_t, &tmp );
				}
			  | SUB_OP INT_CONST
				{
					int tmp = -$2;
					$$ = createConstAttr( INTEGER_t, &tmp );
				}
			  | FLOAT_CONST
				{
					float tmp = $1;
					$$ = createConstAttr( FLOAT_t, &tmp );
				}
			  | SUB_OP FLOAT_CONST
			    {
					float tmp = -$2;
					$$ = createConstAttr( FLOAT_t, &tmp );
				}
			  | SCIENTIFIC
				{
					double tmp = $1;
					$$ = createConstAttr( DOUBLE_t, &tmp );
				}
			  | SUB_OP SCIENTIFIC
				{
					double tmp = -$2;
					$$ = createConstAttr( DOUBLE_t, &tmp );
				}
			  | STR_CONST
				{
					$$ = createConstAttr( STRING_t, $1 );
				}
			  | TRUE
				{
					SEMTYPE tmp = __TRUE;
					$$ = createConstAttr( BOOLEAN_t, &tmp );
				}
			  | FALSE
				{
					SEMTYPE tmp = __FALSE;
					$$ = createConstAttr( BOOLEAN_t, &tmp );
				}
			  ;
%%

int yyerror( char *msg )
{
    fprintf( stderr, "\n|--------------------------------------------------------------------------\n" );
	fprintf( stderr, "| Error found in Line #%d: %s\n", linenum, buf );
	fprintf( stderr, "|\n" );
	fprintf( stderr, "| Unmatched token: %s\n", yytext );
	fprintf( stderr, "|--------------------------------------------------------------------------\n" );
	exit(-1);
}


