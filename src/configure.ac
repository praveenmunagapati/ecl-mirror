dnl				dnl 
dnl  This is an autoconf script.
dnl  To rebuild the `configure' script from this, execute the command
dnl 	autoconf
dnl  in the directory containing this script.
dnl
dnl  AUTOCONF configuration for ECL
dnl  Giuseppe Attardi 25.1.1994
dnl

AC_INIT([ecl],[16.1.3],[])
AC_REVISION([$Revision$])
AC_CONFIG_SRCDIR([bare.lsp.in])
AC_CONFIG_AUX_DIR([gmp])
AC_PREREQ(2.69)

dnl -----------------------------------------------------------------------
dnl Make sure we do not configure within source directory
if test -f configure; then
  AC_MSG_ERROR([This program cannot be built within the source directory])
fi

dnl -----------------------------------------------------------------------
dnl Configure switches

AC_ARG_WITH(cross_config,
  AS_HELP_STRING( [--with-cross-config=f],
                  [supply configuration for a cross compiler]),
  [], [with_cross_config="`pwd`/cross_config"])

AC_ARG_ENABLE(shared,
  AS_HELP_STRING( [--enable-shared],
                  [enable loading compiled files (default=YES)]),
  [], [enable_shared=yes])

AC_ARG_ENABLE(rpath,
  AS_HELP_STRING( [--enable-rpath],
		  [hard-code the location of the ECL shared library.]
		  [(no|yes, default=NO)]),
  [], [enable_rpath=yes] )

AC_ARG_ENABLE(threads,
  AS_HELP_STRING( [--enable-threads],
                  [support for native threads (yes|no|auto, default=auto).]),
  [], [enable_threads=auto])

AC_ARG_ENABLE(boehm,
  AS_HELP_STRING( [--enable-boehm],
                  [use the Boehm-Weiser garbage collector]
                  [(no|included|system|auto, default=auto)] ),
  [], [enable_boehm=auto] )

AC_ARG_ENABLE(libatomic,
  AS_HELP_STRING( [--enable-libatomic],
                  [version of the libatomic-ops library]
                  [(auto|included|system, default=auto)] ),
  [], [enable_libatomic=auto] )

AC_ARG_ENABLE(soname,
  AS_HELP_STRING( [--enable-soname],
		  [link and install the library using version numbers]
		  [(no|yes, default=yes)]),
  [], [enable_soname=yes] )

AC_ARG_ENABLE(gmp,
  AS_HELP_STRING( [--enable-gmp],
                  [version of the GMP library]
                  [(portable|included|system|auto, default=auto)] ),
  [], [enable_gmp=auto] )

dnl GMP library options
AC_ARG_WITH(C-gmp,
  AS_HELP_STRING( [--with-C-gmp],
                  [Deprecated! See --enable-gmp]),
  [with_c_gmp=yes; with_system_gmp=no], [with_c_gmp=no])

AC_ARG_WITH(system-gmp,
  AS_HELP_STRING( [--with-system-gmp],
                  [Derpecated! See --enable-gmp]),
  [], [with_system_gmp="auto"])

AC_ARG_WITH(gmp,
  AS_HELP_STRING( [--with-gmp=args],
                  [Deprecated! See --with-gmp-args]),
  [], [with_gmp_args=""])

AC_ARG_WITH(gmp-args,
  AS_HELP_STRING( [--with-gmp-args=args],
                  [supply arguments for configuring GMP library]),
  [], [with_gmp_args=""])

AC_ARG_WITH(gmp-prefix,
  AS_HELP_STRING( [--with-gmp-prefix=path],
                  [prefix for system GMP includes and libraries] ),
  [GMP_INCDIR="$withval/include"; GMP_LIBDIR="$withval/lib"], [])

AC_ARG_WITH(gmp-incdir,
  AS_HELP_STRING( [--with-gmp-incdir=path],
		  [path to system GMP includes (overrides prefix)] ),
  [GMP_INCDIR="$withval"], [])

AC_ARG_WITH(gmp-libdir,
  AS_HELP_STRING( [--with-gmp-libdir=path],
		  [path to system GMP libraries (overrides prefix)] ),
  [GMP_LIBDIR="$withval"], [])

dnl LIBFFI library options
AC_ARG_WITH(libffi-prefix,
  AS_HELP_STRING( [--with-libffi-prefix=path],
                  [prefix for system LIBFFI includes and libraries] ),
  [LIBFFI_INCDIR="$withval/include"; LIBFFI_LIBDIR="$withval/lib"], [])

AC_ARG_WITH(libffi-incdir,
  AS_HELP_STRING( [--with-libffi-incdir=path],
		  [path to system LIBFFI includes (overrides prefix)] ),
  [LIBFFI_INCDIR="$withval"], [])

AC_ARG_WITH(libffi-libdir,
  AS_HELP_STRING( [--with-libffi-libdir=path],
		  [path to system LIBFFI libraries (overrides prefix)] ),
  [LIBFFI_LIBDIR="$withval"], [])

dnl
AC_ARG_WITH(__thread,
  AS_HELP_STRING( [--with-__thread],
                  [Enable __thread thread-local variables (yes|NO|auto)]
                  [(supported by NPTL-aware glibc and maybe Windows)] ),
  [], [with___thread=no])

AC_ARG_ENABLE(opcode8,
  AS_HELP_STRING( [--enable-opcode8],
                  [Deprecated! interpreter uses 8-bit codes (default=NO, only works on Intel)]),
  [opcode8=${enableval}], [opcode8=no])

AC_ARG_WITH(cxx,
  AS_HELP_STRING( [--with-cxx],
                  [build ECL using C++ compiler (default=NO)]),
  [], [with_cxx=no])

AC_ARG_WITH(tcp,
  AS_HELP_STRING( [--with-tcp],
                  [include socket interface (yes|builtin|no, default=YES)]),
  [], [with_tcp=yes])

AC_ARG_WITH(serve_event,
  AS_HELP_STRING( [--with-serve-event],
                  [include serve-event module (yes|builtin|no, default=YES)]),
  [], [with_serve_event=${enable_shared}])

AC_ARG_WITH(clos-streams,
  AS_HELP_STRING( [--with-clos-streams],
                  [user defined stream objects (yes|builtin|no, default=YES)]),
  [], [with_clos_streams=yes])

AC_ARG_WITH(cmuformat,
  AS_HELP_STRING( [--with-cmuformat],
                  [use CMUCL's FORMAT routine (default=YES)]),
  [], [with_cmuformat=${with_clos_streams}])

AC_ARG_WITH(asdf,
  AS_HELP_STRING( [--with-asdf],
                  [include ASDF building facility]
                  [(yes|builtin|no, default=YES)]),
  [], [with_asdf=yes])

AC_ARG_WITH(defsystem,
  AS_HELP_STRING( [--with-defsystem],
                  [include DEFSYSTEM building facility]
                  [(yes|builtin|no, default=YES)]),
  [], [with_defsystem=yes])

AC_ARG_WITH(cmp,
  AS_HELP_STRING( [--with-cmp],
                  [build the compiler (yes|builtin|no, default=YES)] ),
  [], [with_cmp=yes])

AC_ARG_WITH(bytecmp,
  AS_HELP_STRING( [--with-bytecmp],
                  [build the bytecodes compiler (yes|builtin|no, default=YES)] ),
  [], [with_bytecmp=yes])

AC_ARG_WITH(rt,
  AS_HELP_STRING( [--with-rt],
                  [include MIT-RT testing environment]
                  [(yes|builtin|no, default=YES)]),
  [], [with_rt=yes])

AC_ARG_WITH(profile,
  AS_HELP_STRING( [--with-profile],
                  [include CMUCL's simple profiler]
                  [(yes|builtin|no, default=YES if Boehm-Weiser garbage collector used)]),
  [], [with_profile=yes])

AC_ARG_WITH(dffi,
  AS_HELP_STRING( [--with-dffi],
                  [dynamic foreign function interface]
                  [(system|included|auto|no, default=AUTO if libffi available)]),
  [enable_libffi=${withval}], [enable_libffi=auto])

AC_ARG_WITH(fpe,
  AS_HELP_STRING( [--with-fpe],
                  [detect floating point exceptions]
                  [(default=YES)]),
  [], [with_fpe=yes])

AC_ARG_WITH(signed-zero,
  AS_HELP_STRING( [--with-signed-zero={yes|no}],
                  [allow for IEEE signed zeros (default=YES).]),
  [], [with_signed_zero="yes"])

AC_ARG_WITH(ieee-fp,
  AS_HELP_STRING( [--with-ieee-fp={yes|no}],
                  [full IEEE floating point system, including denormals (default=YES).]
                  [Implies signed-zero and fpe]),
  [], [with_ieee_fp="yes"])

AC_ARG_WITH(sse,
  AS_HELP_STRING( [--with-sse={yes|no|auto}],
                  [implement SSE intrinsics in ECL (default=NO).]
                  [Only works when supported by the compiler]),
  [], [with_sse="no"])

AC_ARG_ENABLE(unicode,
  AS_HELP_STRING( [--enable-unicode={yes|no|32}],
                  [enable support for unicode (default=YES)]),
  [], [enable_unicode=yes])

AC_ARG_ENABLE(longdouble,
  AS_HELP_STRING( [--enable-longdouble],
                  [include support for long double]
                  [(yes|no|auto, default=AUTO)]),
  [enable_longdouble=${enableval}], [enable_longdouble=yes])

AC_ARG_ENABLE(c99complex,
  AS_HELP_STRING( [--enable-c99complex],
                  [include support for C complex type]
                  [(default=NO)]),
  [enable_c99complex=${enableval}], [enable_c99complex=no])

AC_ARG_ENABLE(hpack,
  AS_HELP_STRING( [--enable-hpack],
                  [hierarchical package names]
                  [(default=YES)]),
  [enable_hpack=${enableval}], [enable_hpack=yes])

AC_ARG_ENABLE(asmapply,
  AS_HELP_STRING( [--enable-asmapply],
                  [enable optimizations written in assembler, EXPERIMENTAL]
                  [(default=NO)]),
  [enable_asmapply=${enableval}],[enable_asmapply=no])

AC_ARG_ENABLE(smallcons,
  AS_HELP_STRING( [--enable-smallcons],
                  [use small (2 words) cons types. Requires Boehm-Weiser gc.]
                  [(default=YES)]),
  [enable_smallcons=${enableval}],[enable_smallcons=yes])

AC_ARG_ENABLE(gengc,
  AS_HELP_STRING( [--enable-gengc],
		  [use generational garbage collection. Requires Boehm-Weiser gc.]
		  [(no|yes, default=NO)]),
  [enable_gengc=${enableval}], [enable_gengc=no] )

AC_ARG_ENABLE(precisegc,
  AS_HELP_STRING( [--enable-precisegc],
		  [use type information during garbage collection. Requires Boehm-Weiser gc (EXPERIMENTAL).]
		  [(no|yes, default=NO)]),
  [enable_precisegc=${enableval}], [enable_precisegc=no] )

AC_ARG_ENABLE(debug,
  AS_HELP_STRING( [--enable-debug],
                 [enable various debugging features]
                 [(default=NO)]),
 [DEBUG_CFLAGS="-g -O0"; CFLAGS="$CFLAGS -g -O0"],[])

AC_ARG_WITH(debug-cflags,
  AS_HELP_STRING( [--with-debug-cflags],
                  [add debug flags to the compiler invocation]
                  [(yes,no,actual flags,default=YES)]),
  [],[with_debug_cflags="no"])

AC_ARG_WITH(profile-cflags,
  AS_HELP_STRING( [--with-profile-cflags],
                  [add profiling flags to the compiler invocation]
                  [(yes,no,actual flags,default=NO)]),
  [],[with_profile_cflags="no"])

AC_ARG_WITH(extra-files,
  AS_HELP_STRING( [--with-extra-files],
                  [list of additional source files (default="")]),
  [with_extra_files="${withval}"], [with_extra_files=""])

AC_ARG_WITH(init-form,
  AS_HELP_STRING( [--with-init-form],
                  [lisp forms to execute at startup (default="(si::top-level t)")]),
  [with_init_form="${withval}"], [with_init_form=""])

AC_ARG_WITH(unicode-names,
  AS_HELP_STRING( [--with-unicode-names],
                  [link in the database of Unicode names]
                  [(YES,no)]),
  [],[with_unicode_names="yes"])

dnl -----------------------------------------------------------------------
dnl Installation directories
AC_ARG_VAR([ecldir], [the directory where *.fas files are installed])
test -z "${ecldir}" && ecldir="${libdir}/ecl-${PACKAGE_VERSION}"
AC_SUBST([ecldir])
AC_ARG_VAR([docdir], [the directory where documentation is installed])
test -z "${docdir}" && docdir="${datadir}/doc/ecl-${PACKAGE_VERSION}"
AC_SUBST([docdir])

dnl -----------------------------------------------------------------------
dnl Initialize variables.
boehm_configure_flags=""

AC_EXEEXT dnl			Guess whether .exe is needed for executables
AC_SUBST(buildir)               dnl For top-level Makefile.in
AC_SUBST(ECL_CFLAGS)            dnl Similar, but specific to ECL (see src/util/ecl-config)
AC_SUBST(DEBUG_CFLAGS)
AC_SUBST(GMP_CPPFLAGS)		dnl CFLAGS needed for compiling with system GMP library
AC_SUBST(GMP_LDFLAGS)		dnl LDFLAGS needed for compiling with system GMP library
AC_SUBST(LIBFFI_LDFLAGS)		dnl LDFLAGS needed for compiling with system LIBFFI library
AC_SUBST(FASL_LIBS)             dnl Libraries to link into all ecl code but not
                                dnl into helper programs.
AC_SUBST(CORE_LIBS, [])         dnl Locally compiled libs to link into
                                dnl ecl/ecl_min/libecl.so and nowhere else.
AC_SUBST(SHARED_LDFLAGS)        dnl Flags for shared libraries linker
AC_SUBST(BUNDLE_LDFLAGS)        dnl Flags for FASL files linker
AC_SUBST(EXTRA_OBJS)            dnl Extra *.o files to be compiled into libecl.a
AC_SUBST(TARGETS, ['bin/ecl$(EXE)'])dnl Versions of ECL to be built 
AC_SUBST(SUBDIRS, [])           dnl Subdirectories that make should process
AC_SUBST(LIBRARIES, [])         dnl GMP, Boehm's GC, etc
AC_SUBST(LSP_LIBRARIES)         dnl Libraries produced by lisp translator
AC_SUBST(LSP_FEATURES, ['*features*']) dnl Symbols to add to *FEATURES* for conditional compilation


dnl -----------------------------------------------------------------------
dnl Guess operating system of host.
AC_CANONICAL_BUILD
AC_CANONICAL_HOST


dnl =====================================================================
dnl Checks for programs
AC_PROG_CC	      # sets variable CC
AC_PROG_CXX           # sets variable CXX
AC_PROG_CPP           # sets variable CPP
AC_PROG_RANLIB        # sets variable RANLIB
AC_PROG_INSTALL       # sets variables INSTALL, INSTALL_DATA, INSTALL_PROGRAM
AC_PROG_LN_S          # sets variable LN_S
AC_PROG_MAKE_SET      # set $(MAKE) if needed
AC_PROG_RANLIB        # set variable RANLIB
AC_CHECK_TOOL([AR],[ar]) # set variable AR to appropriate `ar' program
AC_CHECK_PROGS([ETAGS],[etags emacs-etags]) # set variable ETAGS to etags program if found

dnl -----------------------------------------------------------------------
dnl Checks which do not come with autoconf (must be after AC_PROG_CC)
ECL_MAKE_ABSOLUTE_SRCDIR
ECL_CROSS_CONFIG
ECL_GUESS_HOST_OS
ECL___THREAD

AC_SUBST(INFOEXT)
AC_SUBST(INSTALL_INFO)
AC_PATH_PROG([INSTALL_INFO], [install-info], [/bin/true], [$PATH:/sbin:/usr/sbin:/usr/etc])
if test -z `which gzip`; then
  INFOEXT=info.gz
else
  INFOEXT=info
fi

dnl ======================================================================
dnl GNU multiprecision library
dnl
dnl This a multi-stage process. First we have to detect whether we must build
dnl the GMP library. If this is the case, then we may have to detect the
dnl build flags for the library, because GMP may choose to build for 64
dnl or 32 bits executables and ECL has to be compiled / linked using precisely
dnl the same flags
dnl
if test "x$GMP_INCDIR" != "x"; then
  GMP_CPPFLAGS="-I$GMP_INCDIR"
fi
if test "x$GMP_LIBDIR" != "x"; then
  GMP_LDFLAGS="-L$GMP_LIBDIR"
  if test "$enable_rpath" = "yes"; then
    if (echo "$ECL_LDRPATH" | grep '~A') > /dev/null; then
      GMP_LDFLAGS=`echo $ECL_LDRPATH | sed "s,~A,$GMP_LIBDIR,"`" $GMP_LDFLAGS"
    fi
  fi
fi
CPPFLAGS="$CPPFLAGS $GMP_CPPFLAGS"
LDFLAGS="$LDFLAGS $GMP_LDFLAGS"

AS_CASE([${enable_gmp}],
        [portable], [with_system_gmp=no; with_c_gmp=yes],
        [included], [with_system_gmp=no],
        [system],   [with_system_gmp=yes],
        [AC_CHECK_LIB( [gmp], [__gmpz_init],
           [with_system_gmp=yes],
           [with_system_gmp=no] )])

ECL_GMP_HEADER=
if test "${with_system_gmp}" = "yes"; then
  AC_CHECK_LIB( [gmp], [__gmpz_init],
    [FASL_LIBS="${FASL_LIBS} -lgmp"],
    [AC_MSG_ERROR([System gmp library requested but not found.])])
  AC_CHECK_HEADER( [gmp.h], [ECL_GMP_HEADER='gmp.h'] )
  if test "x$ECL_GMP_HEADER" = "x"; then
    AC_CHECK_HEADER( [gmp/gmp.h], [ECL_GMP_HEADER='gmp/gmp.h'] )
  fi
else
  SUBDIRS="${SUBDIRS} gmp"
  CORE_LIBS="-leclgmp ${CORE_LIBS}"
  if test ${enable_shared} = "no"; then
    LIBRARIES="${LIBRARIES} ${LIBPREFIX}eclgmp.${LIBEXT}"
  fi
fi

dnl ----------------------------------------------------------------------
dnl Configure local GMP if needed
AC_SUBST(ECL_GMP_HEADER)
EXTRA_OBJS="${EXTRA_OBJS} c/big.o"
if test "x${with_system_gmp}" = "xno" ; then
  AC_MSG_NOTICE(Configuring included GMP library:)
  test -d gmp && rm -rf gmp
  if test -z "$gmp_build"; then
    gmp_build="${build}"
  fi
  if test "x$with_c_gmp" = "xyes"; then
    gmp_build=`echo ${gmp_build} | sed 's,@<:@^-@:>@*\(-.*\),none\1,'`
    echo '***'
    echo '***' BUILDING GMP WITH C!
    echo '***' This is a last resort, either because of license or
    echo '***' porting issues.
    echo '***'
  fi
  ECL_GMP_HEADER='ecl/gmp.h'
  if test "x$ABI" = "x"; then
    GMP_ABI=""
  else
    GMP_ABI="ABI=$ABI"
  fi
  # Crosscompilation for Android on Darwin requires replacing 'NM=nm'
  # below with 'NM=$PLATFORM_PREFIX/bin/arm-linux-androideabi-nm'.
  mkdir gmp
  dnl Notice we need -DPIC to force the assembler to generate PIC code
  (destdir=`${PWDCMD}`; cd gmp && CC="${CC} ${PICFLAG}" \
     $srcdir/gmp/configure --disable-shared --prefix=${destdir} \
     -infodir=${destdir}/doc --includedir=${destdir}/ecl --with-pic \
     --libdir=${destdir} --build=${gmp_build} --host=${host_alias} \
     CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" CPPFLAGS="$CPPFLAGS" CC="${CC} ${PICFLAG}" \
     "$GMP_ABI" $with_gmp_args)
  if test ! -f gmp/config.status; then
    AC_MSG_ERROR([Failed to configure the GMP library.])
  fi
else
  if test "x$ECL_GMP_HEADER" = "x"; then
    AC_MSG_ERROR([Can not find GMP header.])
  fi
fi

dnl -----------------------------------------------------------------------
dnl GMP-based search of C/C++ compiler and linker flags
AC_MSG_CHECKING([GMP autoconf])
AC_MSG_RESULT(["${with_system_gmp}.${enable_slow_config}"])
if test "x${enable_slow_config}" = "xyes"; then
  with_system_gmp=no
fi
if test "x${with_system_gmp}" = "xno"; then
  ECL_GMP_BASED_CONFIG
fi

dnl ======================================================================
dnl LIBFFI library
if test "x$LIBFFI_INCDIR" != "x"; then
  LIBFFI_CPPFLAGS="-I$LIBFFI_INCDIR"
fi
if test "x$LIBFFI_LIBDIR" != "x"; then
  LIBFFI_LDFLAGS="-L$LIBFFI_LIBDIR"
  if test "$enable_rpath" = "yes"; then
    if (echo "$ECL_LDRPATH" | grep '~A') > /dev/null; then
      LIBFFI_LDFLAGS=`echo $ECL_LDRPATH | sed "s,~A,$LIBFFI_LIBDIR,"`" $LIBFFI_LDFLAGS"
    fi
  fi
fi
CPPFLAGS="$CPPFLAGS $LIBFFI_CPPFLAGS"
LDFLAGS="$LDFLAGS $LIBFFI_LDFLAGS"

dnl =====================================================================
dnl Checks for libraries

AC_CHECK_LIB(sun, getpwnam)         # on IRIX adds -lsun
AC_SEARCH_LIBS([strerror],[cposix])

dnl ----------------------------------------------------------------------
dnl Profiling & debug flags
dnl
if test "$with_debug_cflags" = "yes"; then
  with_debug_cflags="-g"
fi
if test "$with_debug_cflags" != "no"; then
  DEBUG_CFLAGS="$with_debug_cflags"
  CFLAGS="$with_debug_cflags $CFLAGS"
  CXXFLAGS="$with_debug_cflags $CXXFLAGS"
  LDFLAGS="$with_debug_cflags $LDFLAGS"
fi
if test "$with_profile_cflags" = "yes"; then
  with_profile_cflags="-pg"
fi
if test "$with_profile_cflags" != "no"; then
  CFLAGS="$with_profile_cflags $CFLAGS"
  CXXFLAGS="$with_profile_cflags $CFLAGS"
  LDFLAGS="$with_profile_cflags $LDFLAGS"
fi

dnl ----------------------------------------------------------------------
dnl Version of the compiler
ECL_CMPDIR=cmp
AC_SUBST(ECL_CMPDIR)

dnl ----------------------------------------------------------------------
dnl Native thread support
if test "${enable_threads}" = "auto"; then
  AC_MSG_CHECKING([for threads support])
  if test -z "${THREAD_OBJ}"; then
    AC_MSG_RESULT([no])
    enable_threads="no"
  else
    AC_MSG_RESULT([yes])
    enable_threads="yes"
  fi
fi
if test "${enable_threads}" = "yes" ; then
  if test -z "${THREAD_OBJ}"; then
    AC_MSG_ERROR([Threads aren't supported on this system.])
  else
    LIBS="${THREAD_LIBS} ${LIBS}"
    CFLAGS="${CFLAGS} ${THREAD_CFLAGS}"
    ECL_POSIX_RWLOCK
    boehm_configure_flags="${boehm_configure_flags} ${THREAD_GC_FLAGS}"
    for k in $THREAD_OBJ; do EXTRA_OBJS="$EXTRA_OBJS ${k}.${OBJEXT}"; done
    AC_MSG_CHECKING([for thread object files])
    AC_MSG_RESULT([${THREAD_OBJ}])
    AC_DEFINE( [ECL_THREADS], [1], [Userland threads?])
    if test "${with___thread}" = "auto"; then
      with___thread=${ac_cv_ecl___thread}
    fi
    AC_MSG_CHECKING([for use of __thread])
    if test "${with___thread}" = "yes"; then
      AC_DEFINE( [WITH___THREAD], [1], [__thread thread-local variables?] )
      AC_MSG_RESULT([yes])
    else
      AC_MSG_RESULT([no])
    fi
  fi
else
  boehm_configure_flags="${boehm_configure_flags} --disable-threads"
fi

dnl ----------------------------------------------------------------------
dnl		Boehm-Weiser garbage collector
if test ${enable_boehm} = "no" ; then
  AC_MSG_ERROR([Boehm GC library is currently needed to build ECL]);
  EXTRA_OBJS="${EXTRA_OBJS} alloc.${OBJEXT} gbc.${OBJEXT}"
  enable_smallcons="no"
else
  ECL_BOEHM_GC
fi
if test ${enable_smallcons} = "yes" ; then
   AC_DEFINE([ECL_SMALL_CONS], [], [ECL_SMALL_CONS])
fi

ECL_LIBFFI

dnl ----------------------------------------------------------------------
dnl SONAME is only active when SONAME_LDFLAGS and SONAME are non nil
dnl
AC_MSG_CHECKING(for soname flags)
PACKAGE_MAJOR=`echo ${PACKAGE_VERSION} | sed -e 's,\(.*\)\..*\..*,\1,g'`
PACKAGE_MINOR=`echo ${PACKAGE_VERSION} | sed -e 's,.*\.\(.*\)\..*,\1,g'`
PACKAGE_LEAST=`echo ${PACKAGE_VERSION} | sed -e 's,.*\..*\.\(.*\),\1,g'`
if test "${enable_soname}" != yes; then
   SONAME=''
   SONAME1=''
   SONAME2=''
   SONAME3=''
   SONAME_ALIASES=''
   SONAME_LDFLAGS=''
   AC_MSG_RESULT([none])
else
   i="${PACKAGE_MAJOR}.${PACKAGE_MINOR}.${PACKAGE_LEAST}"
   SONAME3=`echo $SONAME | sed "s,.SOVERSION,.$i,g"`
   i="${PACKAGE_MAJOR}.${PACKAGE_MINOR}"
   SONAME2=`echo $SONAME | sed "s,.SOVERSION,.$i,g"`
   i="${PACKAGE_MAJOR}"
   SONAME1=`echo $SONAME | sed "s,.SOVERSION,.$i,g"`
   SONAME=`echo $SONAME | sed "s,.SOVERSION,,g"`
   SONAME_LDFLAGS=`echo $SONAME_LDFLAGS | sed "s,SONAME,$SONAME2,g"`
   AC_MSG_RESULT([${SONAME_LDFLAGS}])
fi
AC_SUBST(SONAME3)
AC_SUBST(SONAME2)
AC_SUBST(SONAME1)
AC_SUBST(SONAME)
AC_SUBST(SONAME_LDFLAGS)

dnl Related to that, the package version number
ECL_VERSION_NUMBER=$(($PACKAGE_MAJOR * 10000 + $PACKAGE_MINOR * 100 + $PACKAGE_LEAST))
AC_SUBST(ECL_VERSION_NUMBER)

dnl ----------------------------------------------------------------------
dnl Deactivate floating point exceptions if asked to
if test "${with_ieee_fp}" = yes; then
   with_signed_zero="yes"
   with_fpe="yes"
   AC_DEFINE([ECL_IEEE_FP], [], [ECL_IEEE_FP])
fi
if test "${with_fpe}" != yes; then
   AC_DEFINE([ECL_AVOID_FPE_H], [], [ECL_AVOID_FPE_H])
fi
if test "${with_signed_zero}" = yes; then
   AC_DEFINE([ECL_SIGNED_ZERO], [], [ECL_SIGNED_ZERO])
fi

dnl =====================================================================
dnl Checks for header files

dnl !!! autoscan
AC_PATH_X
AC_HEADER_DIRENT
AC_HEADER_STDBOOL
AC_HEADER_STDC
AC_HEADER_TIME
AC_CHECK_HEADERS( [fcntl.h limits.h netdb.h netinet/in.h] \
                  [stddef.h stdlib.h string.h sys/param.h] \
                  [sys/socket.h sys/time.h unistd.h fenv.h] \
		  [sched.h] )
dnl !!! end autoscan

AC_CHECK_HEADERS( [sys/resource.h sys/utsname.h float.h pwd.h dlfcn.h link.h] \
                  [mach-o/dyld.h dirent.h sys/ioctl.h sys/select.h] \
                  [sys/wait.h semaphore.h] )


AC_CHECK_HEADERS([ulimit.h], [], [],
[[#ifdef HAVE_ULIMIT_H
# include <ulimit.h>
#endif
]])

dnl =====================================================================
dnl Checks for typedefs, structures, and compiler characteristics.

dnl !!! autoscan
AC_C_CONST                      dnl !!! DNLed
AC_C_INLINE
AC_TYPE_SIZE_T                  dnl !!! DNLed
AC_STRUCT_TM
AC_C_VOLATILE
AC_CHECK_TYPES([ptrdiff_t])
ECL_LONG_LONG
dnl !!! end autoscan

dnl !!! dnled in original
dnl AC_TYPE_PID_T          # DEFS pid_t
dnl AC_TYPE_UID_T          # DEFS uid_t, gid_t
dnl AC_TYPE_OFF_T	   # DEFS off_t
dnl AC_C_CHAR_UNSIGNED     # DEFS __CHAR_UNSIGNED__ if char is unsigned
dnl !!! end dnled

AC_C_BIGENDIAN([], [],
  [AC_DEFINE(WORDS_BIGENDIAN, [/* EDIT! - Undefine if small endian */])])

dnl ----------------------------------------------------------------------
dnl This flag is an optimization for GNU
dnl if test "${GCC}" = "yes"; then
dnl  CFLAGS="${CFLAGS} -fstrict-aliasing"
dnl fi

dnl ----------------------------------------------------------------------
dnl Check the appropiate type for cl_fixnum/cl_index
ECL_FIXNUM_TYPE
ECL_INTEGER_TYPES

ECL_LINEFEED_MODE
ECL_FIND_SETJMP
ECL_FILE_STRUCTURE
ECL_FPE_MODEL
ECL_SSE
ECL_LONG_DOUBLE
if test "$enable_c99complex" != "no" ; then
AC_CHECK_TYPES([double complex, float complex],[],[],[#include <complex.h>])
fi

dnl -----------------------------------------------------------------------
dnl Study the call conventions
ECL_STACK_DIRECTION

dnl =====================================================================
dnl Checks for library functions

dnl !!! autoscan
AC_FUNC_CLOSEDIR_VOID
AC_FUNC_ERROR_AT_LINE
AC_FUNC_FORK
AC_PROG_GCC_TRADITIONAL
AC_FUNC_MALLOC
AC_FUNC_MEMCMP
AC_FUNC_MMAP
AC_FUNC_REALLOC
AC_FUNC_SELECT_ARGTYPES
AC_TYPE_SIGNAL
AC_FUNC_STAT
AC_FUNC_STRTOD
AC_CHECK_FUNCS( [floor getcwd gethostbyaddr gethostbyname getpagesize] \
                [memmove memset mkdir putenv socket sqrt] \
                [strcasecmp strchr strerror strtol] )
dnl !!! end autoscan

AC_CHECK_FUNCS( [nanosleep alarm times select setenv putenv] \
                [lstat mkstemp sigprocmask isatty tzset] \
		[gettimeofday getrusage] )

AC_CHECK_FUNCS( [ feenableexcept ] )

AC_CHECK_FUNCS( [expf logf sqrtf cosf sinf tanf sinhf coshf tanhf] \
		[floorf ceilf fabsf frexpf ldexpf log1p log1pf log1pl] \
                [copysign] )

AC_CHECK_FUNCS( [sched_yield uname fseeko dladdr backtrace backtrace_symbols] )

AC_CHECK_HEADER( [sys/mman.h],
                 AC_DEFINE([ECL_USE_MPROTECT], [], [ECL_USE_MPROTECT])
                 AC_DEFINE([HAVE_SYS_MMAN_H], [], [HAVE_SYS_MMAN_H])
               )

ECL_POSIX_ENVIRON

dnl =====================================================================
dnl Checks for system services

dnl =====================================================================
dnl Final pass over configuration files
dnl
dnl Notice that we build ${builddir}/ecl/configpre.h from
dnl ${srcdir}/ecl/config.h.in, and then use all AC_DEF* to build
dnl ecl/config.h from ecl/configpre.h

dnl ----------------------------------------------------------------------
dnl Do we use C or C++ compiler to compile ecl?
if test ${with_cxx} = "no" ; then
  AC_SUBST([ECL_CC], [${CC}])
else
  AC_SUBST([ECL_CC], [${CXX}])
  AC_DEFINE([ECL_CXX_CORE], [1],
            [Do we use C or C++ compiler to compile ecl?])
  boehm_configure_flags="${boehm_configure_flags} --enable-cplusplus"
fi

dnl ----------------------------------------------------------------------
dnl Do we need to have 8-bit opcodes?
if test ! ${opcode8} = "no" ; then
  AC_DEFINE( ECL_SMALL_BYTECODES, [1], 
             [Bytecodes and arguments are 8 and 16 bits large, respectively])
fi

ECL_GCC_BACKTRACE
ECL_LIBATOMIC_OPS

dnl ----------------------------------------------------------------------
dnl Lisp library and libecl features
if test ${enable_shared} = "yes"; then
  AC_DEFINE(ENABLE_DLOPEN, [1], [Allow loading dynamically linked code])
  LSP_LIBRARIES="${SHAREDPREFIX}ecl.${SHAREDEXT}"
  ECL_ADD_LISP_MODULE([dlopen])
else
  enable_soname=no
  LSP_LIBRARIES="${LIBPREFIX}ecl.${LIBEXT}"
  ECL_LDRPATH=''
fi

if test "x${enable_rpath}" = "xno"; then
  ECL_LDRPATH=''
fi

if test "${with_cmuformat}" = "yes"; then
  with_clos_streams="yes"
  AC_DEFINE([ECL_CMU_FORMAT], [1], [Use CMU Common-Lisp's FORMAT routine])
fi

if test "${with_clos_streams}" = "yes"; then
  AC_DEFINE( ECL_CLOS_STREAMS, [1],
             [Allow STREAM operations to work on arbitrary objects])
fi

if test "${with_cmp}" = "builtin"; then
  ECL_ADD_BUILTIN_MODULE([cmp])
  with_cmp=yes
fi
if test "${with_cmp}" = "yes"; then
  ECL_ADD_LISP_MODULE([cmp])
fi

if test "${with_tcp}" = "builtin"; then
  ECL_ADD_BUILTIN_MODULE([sockets])
  with_tcp=yes
fi
if test "${with_tcp}" = "yes"; then
  AC_DEFINE(TCP, [1], [Network streams])
  EXTRA_OBJS="${EXTRA_OBJS} c/tcp.${OBJEXT}"
  ECL_ADD_LISP_MODULE([sockets])
  LIBS="${LIBS} ${TCPLIBS}"
fi

if test "${with_serve_event}" = "builtin"; then
  ECL_ADD_BUILTIN_MODULE([serve_event])
  with_serve_event=yes
fi
if test "${with_serve_event}" = "yes"; then
  case "${host_os}" in
    mingw*|cygwin*) ;;
    *)
      ECL_ADD_LISP_MODULE([serve-event])
    ;;
  esac
fi

if test "${with_asdf}" = "builtin"; then
  ECL_ADD_BUILTIN_MODULE([asdf])
  with_asdf=yes
fi
if test "${with_asdf}" = "yes"; then
  ECL_ADD_LISP_MODULE([asdf])
fi

if test "${with_defsystem}" = "builtin"; then
  ECL_ADD_BUILTIN_MODULE([defsystem])
  with_defsystem=yes
fi
if test "${with_defsystem}" = "yes"; then
  ECL_ADD_LISP_MODULE([defsystem])
fi

if test "${with_profile}" = "builtin"; then
  ECL_ADD_BUILTIN_MODULE([profile])
  with_profile=yes
fi
if test "${with_profile}" = "yes"; then
  if test "${enable_boehm}" != "no"; then
    ECL_ADD_LISP_MODULE([profile])
  fi
fi

if test "${with_bytecmp}" = "builtin"; then
  ECL_ADD_BUILTIN_MODULE([bytecmp])
  with_bytecmp=yes
fi
if test "${with_bytecmp}" = "yes"; then
  ECL_ADD_LISP_MODULE([bytecmp])
fi

if test "${with_rt}" = "builtin"; then
  ECL_ADD_BUILTIN_MODULE([rt])
  with_rt=yes
fi
if test "${with_rt}" = "yes"; then
  ECL_ADD_LISP_MODULE([rt])
fi

if test "x${enable_unicode}" != "xno"; then
   if test "${enable_unicode}" = 16; then
      AC_DEFINE([ECL_UNICODE], [16], [Support for Unicode])
      CHAR_CODE_LIMIT=65536
      ECL_CHARACTER=$ECL_INT16_T
      EXTRA_OBJS="$EXTRA_OBJS unicode/ucd16.o unicode/ucd16-0000.o unicode/ucd16-0016.o unicode/ucd16-0032.o unicode/ucd16-0048.o unicode/ucd16-0064.o"
   else
      AC_DEFINE([ECL_UNICODE], [21], [Support for Unicode])
      CHAR_CODE_LIMIT=1114112
      ECL_CHARACTER=$ECL_INT32_T
      EXTRA_OBJS="$EXTRA_OBJS c/unicode/ucd.o c/unicode/ucd-0000.o c/unicode/ucd-0016.o c/unicode/ucd-0032.o c/unicode/ucd-0048.o c/unicode/ucd-0064.o c/unicode/ucd-0080.o c/unicode/ucd-0096.o"
   fi
   if test "${with_unicode_names}" = "yes"; then
      AC_DEFINE([ECL_UNICODE_NAMES], [1], [Link in the database of Unicode names])
      EXTRA_OBJS="$EXTRA_OBJS c/unicode/ucd_names_char.o c/unicode/ucd_names_codes.o c/unicode/ucd_names_pair.o c/unicode/ucd_names_str.o"
   fi
else
   CHAR_CODE_LIMIT=256
   ECL_CHARACTER="int"
fi
AC_SUBST(ECL_CHARACTER)
AC_SUBST(CHAR_CODE_LIMIT)

AC_SUBST(ECL_EXTRA_LISP_FILES)
ECL_EXTRA_LISP_FILES=""
for i in $with_extra_files; do
  ECL_EXTRA_LISP_FILES="${ECL_EXTRA_LISP_FILES} \"$i\""
done
AC_SUBST(ECL_INIT_FORM)
echo ${with_init_form} = init form
if test "x${with_init_form}" = "x"; then
  ECL_INIT_FORM='(SI::TOP-LEVEL T)'
else
  ECL_INIT_FORM="${with_init_form}"
fi

if test "${enable_hpack}" = "yes"; then
   AC_DEFINE([ECL_RELATIVE_PACKAGE_NAMES], [1], [Hierarchical package names])
fi

AC_CONFIG_FILES([
  bare.lsp
  lsp/load.lsp
  clos/load.lsp
  cmp/load.lsp
  ../Makefile
  Makefile
  doc/Makefile
  doc/ecl.man
  doc/ecl-config.man
  ecl/configpre.h:h/config.h.in
  ecl/configpre-int.h:h/config-internal.h.in
  bin/ecl-config.pre:util/ecl-config
  lsp/config.lsp:lsp/config.lsp.in
  compile.pre:compile.lsp.in
  cmp/cmpdefs.pre:cmp/cmpdefs.lsp
  tests/config.lsp
  tests/Makefile
 ])

AC_CONFIG_HEADERS([ecl/config.h:ecl/configpre.h])
AC_CONFIG_HEADERS([ecl/config-internal.h:ecl/configpre-int.h])
AC_OUTPUT

for i in $srcdir/c/*/; do mkdir -p c/`basename $i`; done
