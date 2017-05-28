%option noyywrap
%x IFILE
%{
	struct bufstack {
		struct bufstack *prev;		/* previous entry */
		YY_BUFFER_STATE bs;		/* saved buffer */
		int lineno;			/* saved line no */
		char *filename;			/* name of this file */
		FILE *f;			/* current file */
	} *curbs = 0;

	char *curfilename;			/* name of current input file */
	int newfile(char *fn);
	int popfile(void);
%}

%%

^"#"[ \t]*include[ \t]*[\"<]	{ BEGIN IFILE; }

<IFILE>[^ \t\n\">]+		{
					{ int c;
					  while((c = input()) && c !='\n');
					}
					yylineno++;
					if (!newfile(yytext))
						yyterminate();
					BEGIN INITIAL;
				}
<IFILE>.|\n			{ fprintf(stderr, "Bad include line at %d", yylineno);
				  yyterminate();
				}
^.				{ fprintf(yyout, "%d\t%s", yylineno, yytext); }
^\n				{ fprintf(yyout, "%d\t%s", yylineno++, yytext); }
.				{ ECHO; }
<<EOF>>				{ if (!popfile()) yyterminate(); }

%%

int main(int argc, char **argv) {
	if (argc < 2) {
		printf("Filename needed\n");
		exit(1);
	}
	if (newfile(argv[1]))
		yylex();
}

int newfile(char *fn) {
	FILE *f = fopen(fn, "r");
	struct bufstack *bs = malloc(sizeof(struct bufstack));

	if (!f) { perror(fn); return 0; }
	if (!bs) { perror("malloc"); exit(1); }

	if (curbs)
		curbs->lineno = yylineno;
	bs->prev = curbs;

	bs->bs = yy_create_buffer(f, YY_BUF_SIZE);
	bs->filename = fn;
	bs->f = f;
	yy_switch_to_buffer(bs->bs);
	curbs = bs;
	curfilename = fn;
	return 1;
}

int popfile(void) {
	struct bufstack *bs = curbs;
	struct bufstack *prev;

	if (!bs) return 0;

	fclose(bs->f);
	yy_delete_buffer(bs->bs);

	prev = bs->prev;
	free(bs);

	if (!prev) return 0;

	yy_switch_to_buffer(prev->bs);
	curbs = prev;
	yylineno = prev->lineno;
	curfilename = prev->filename;
	return 1;
}
