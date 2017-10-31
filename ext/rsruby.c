/*
* == Author
* Alex Gutteridge
*
* == Copyright
*Copyright (C) 2006 Alex Gutteridge
*
* The Original Code is the RPy python module.
*
* The Initial Developer of the Original Code is Walter Moreira.
* Portions created by the Initial Developer are Copyright (C) 2002
* the Initial Developer. All Rights Reserved.
*
* Contributor(s):
*    Gregory R. Warnes <greg@warnes.net> (RPy Maintainer)
*
*This library is free software; you can redistribute it and/or
*modify it under the terms of the GNU Lesser General Public
*License as published by the Free Software Foundation; either
*version 2.1 of the License, or (at your option) any later version.
*
*This library is distributed in the hope that it will be useful,
*but WITHOUT ANY WARRANTY; without even the implied warranty of
*MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
*Lesser General Public License for more details.
*
*You should have received a copy of the GNU Lesser General Public
*License along with this library; if not, write to the Free Software
*Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
*/

#include "rsruby.h"
#include "r_config.h"
#include <stdlib.h>

/* Global list to protect R objects from garbage collection */
/* This is inspired in $R_SRC/src/main/memory.c */
static SEXP R_References;
void protect_robj(SEXP robj){
  R_PreserveObject(robj);
}

SEXP
RecursiveRelease(SEXP obj, SEXP list)
{
  if (!isNull(list)) {
    if (obj == CAR(list))
      return CDR(list);
    else
      SETCDR(list, RecursiveRelease(obj, CDR(list)));
  }
  return list;
}

/* TODO: This needs implementing as a Ruby destructor for each RObj */
void
Robj_dealloc(SEXP robj)
{
  R_ReleaseObject(robj);

}


/* Obtain an R object via its name.
 * This is only used to get the 'get' function.
 * All subsequent calls go via the 'get' function itself
 */
VALUE get_fun(VALUE self, VALUE name){

  VALUE str;
  int conversion=TOP_MODE;
  SEXP robj;
  VALUE  rubyobj;
  char* cstr_name;

  str = StringValue(name);

  cstr_name = RSTRING_PTR(str);

  robj = (SEXP)get_fun_from_name(cstr_name);
  if (!robj)
    return Qnil;

  /* Wrap the returned R object as a ruby Object */
  rubyobj = Data_Wrap_Struct(rb_const_get(rb_cObject,
					  rb_intern("RObj")), 0, &Robj_dealloc , robj);
  rb_iv_set(rubyobj,"@conversion",INT2FIX(conversion));
  rb_iv_set(rubyobj,"@wrap",Qfalse);

  return rubyobj;

}

//TODO - This function does not appear to be working correctly
void r_finalize(void)
{
  unsigned char buf[1024];
  char * tmpdir;

  R_dot_Last();
  R_gc();  /* Remove any remaining R objects from memory */
}

/*
 * Shutdown the R interpreter
 */
VALUE rs_shutdown(VALUE self){

  r_finalize();
  Rf_endEmbeddedR(0);
  return Qtrue;

}

/*
 * Starts the R interpreter.
 */
VALUE rr_init(VALUE self, VALUE r_argv){

  char **argv;
  int i, argc = 1;
  VALUE arg;

  switch (TYPE(r_argv)) {

    case T_ARRAY:

      argv = (char **)calloc(RARRAY_LEN(r_argv) + 1, sizeof(char *));
      if (argv == NULL) rb_raise(rb_eTypeError, "rr_init could not allocate memory");

      for (i = 0; i < RARRAY_LEN(r_argv); i++) {
        arg = rb_ary_entry(r_argv, i);
        if (TYPE(arg) == T_STRING) {
          argv[i+1] = (char *)malloc((RSTRING_LEN(arg) + 1) * sizeof(char));
          strcpy(argv[i+1], StringValueCStr(arg));
        }
        else rb_raise(rb_eTypeError, "rr_init array input must contain only strings");
      }

      argc += RARRAY_LEN(r_argv);
      break;

    default:
      rb_raise(rb_eTypeError, "rr_init must receive an array of strings or NULL");
      break;
  }


  argv[0] = (char *)malloc((strlen("rsruby") + 1) * sizeof(char));
  if (argv[0] == NULL) rb_raise(rb_eTypeError, "rr_init could not allocate memory");
  strcpy(argv[0], "rsruby");

  init_R(argc, argv);

  // Initialize the list of protected objects
  R_References = R_NilValue;
  SET_SYMVALUE(install("R.References"), R_References);

  for (i = 0; i < argc; i++)
    free(argv[i]);
  free(argv);

  return self;

}

/*
 * Initialises the R interpreter.
 */
void init_R(int argc, char **argv){

  if (RSRUBY_R_HOME) {
    setenv("R_HOME", RSRUBY_R_HOME, 0);
  }

  Rf_initialize_R(argc, argv);
  R_Interactive = TRUE;
  R_CStackLimit = (uintptr_t)-1; //disable stack limit checking
  setup_Rmainloop();
  R_Interactive = FALSE; //Remove crash menu (and other interactive R features)
}

/* This method is for testing catching of segfaults */
VALUE crash(){
  int* ptr = (int*)0;
  *ptr = 1;
  return Qtrue;
}


/* Ruby code */

VALUE cRRuby;
VALUE cRObj;

void Init_rsruby_c(){

  cRRuby = rb_define_class("RSRuby",rb_cObject);

  rb_define_method(cRRuby, "r_init", rr_init, 1);
  rb_define_method(cRRuby, "get_fun", get_fun, 1);
  rb_define_method(cRRuby, "shutdown", rs_shutdown, 0);

  rb_define_method(cRRuby, "crash", crash, 0);
  rb_define_method(cRRuby, "to_R", ruby_to_Robj, 1);

  //Add the lcall method to RObj
  cRObj  = rb_const_get(rb_cObject,rb_intern("RObj"));
  rb_define_method(cRObj, "lcall", RObj_lcall, 1);
  rb_define_method(cRObj, "__init_lcall__", RObj_init_lcall, 1);
  rb_define_method(cRObj, "to_ruby", RObj_to_ruby, -2);


}
