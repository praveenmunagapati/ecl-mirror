/* -*- mode: c; c-basic-offset: 8 -*- */
/*
    unixsys.s  -- Unix shell interface.
*/
/*
    Copyright (c) 1984, Taiichi Yuasa and Masami Hagiya.
    Copyright (c) 1990, Giuseppe Attardi.
    Copyright (c) 2001, Juan Jose Garcia Ripoll.

    ECL is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    See file '../Copyright' for full details.
*/

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <fcntl.h>
#if !defined(_MSC_VER)
# include <unistd.h>
#endif
#include <ecl/ecl.h>
#include <ecl/internal.h>
#if defined(ECL_MS_WINDOWS_HOST)
# include <windows.h>
#endif
#ifdef HAVE_SYS_WAIT_H
# include <sys/wait.h>
#endif
#include <ecl/ecl-inl.h>

/* Mingw defines 'environ' to be a macro instead of a global variable. */
#ifdef environ
# undef environ
#endif

cl_object
si_system(cl_object cmd_string)
{
	cl_object cmd = si_copy_to_simple_base_string(cmd_string);
	int code = system((const char *)(cmd->base_string.self));
	/* FIXME! Are there any limits for system()? */
	/* if (cmd->base_string.fillp >= 1024)
		FEerror("Too long command line: ~S.", 1, cmd);*/
	/* FIXME! This is a non portable way of getting the exit code */
	@(return MAKE_FIXNUM(code >> 8))
}

cl_object
si_getpid(void)
{
	@(return MAKE_FIXNUM(getpid()))
}

cl_object
si_getuid(void)
{
#if defined(ECL_MS_WINDOWS_HOST)
        @(return MAKE_FIXNUM(0));
#else
	@(return ecl_make_integer(getuid()));
#endif
}

ecl_def_ct_base_string(fake_in_name, "PIPE-READ-ENDPOINT", 18, static, const);
ecl_def_ct_base_string(fake_out_name, "PIPE-WRITE-ENDPOINT", 19, static, const);

cl_object
si_make_pipe()
{
	cl_object output;
	int fds[2], ret;
#if defined(ECL_MS_WINDOWS_HOST)
	ret = _pipe(fds, 4096, _O_BINARY);
#else
	ret = pipe(fds);
#endif
	if (ret < 0) {
		FElibc_error("Unable to create pipe", 0);
		output = Cnil;
	} else {
		cl_object in = ecl_make_stream_from_fd(fake_in_name, fds[0], smm_input, 8,
						       ECL_STREAM_DEFAULT_FORMAT, Cnil);
		cl_object out = ecl_make_stream_from_fd(fake_out_name, fds[1], smm_output, 8,
						       ECL_STREAM_DEFAULT_FORMAT, Cnil);
		output = cl_make_two_way_stream(in, out);
	}
	@(return output)
}

static cl_object
from_list_to_execve_argument(cl_object l, char ***environp)
{
        cl_object p;
        cl_index i, j, total_size = 0, nstrings = 0;
        cl_object buffer;
        char **environ;
        for (p = l; !Null(p); p = ECL_CONS_CDR(p)) {
                cl_object s;
                if (!CONSP(p)) {
                        FEerror("In EXT:RUN-PROGRAM, environment "
                                "is not a list of strings", 0);
                }
                s = ECL_CONS_CAR(p);
                if (!ECL_BASE_STRING_P(s)) {
                        FEerror("In EXT:RUN-PROGRAM, environment "
                                "is not a list of base strings", 0);
                }
                total_size += s->base_string.fillp + 1;
                nstrings++;
        }
        /* Extra place for ending null */
        total_size++;
        buffer = ecl_alloc_simple_base_string(++total_size);
        environ = ecl_alloc_atomic((nstrings + 1) * sizeof(char*));
        for (j = i = 0, p = l; !Null(p); p = ECL_CONS_CDR(p)) {
                cl_object s = ECL_CONS_CAR(p);
                cl_index l = s->base_string.fillp;
                if (i + l + 1 >= total_size) {
                        FEerror("In EXT:RUN-PROGRAM, environment list"
                                " changed during execution.", 0);
                        break;
                }
                environ[j++] = (char*)(buffer->base_string.self + i);
                memcpy(buffer->base_string.self + i,
                       s->base_string.self,
                       l);
                i += l;
                buffer->base_string.self[i++] = 0;
        }
        buffer->base_string.self[i++] = 0;
        environ[j] = 0;
        if (environp) *environp = environ;
        return buffer;
}

static cl_object
make_external_process(cl_object pid, cl_object input, cl_object output)
{
        return cl_funcall(4, @'ext::make-external-process', pid, input, output);
}

#if defined(ECL_MS_WINDOWS_HOST)
cl_object
si_close_windows_handle(cl_object h)
{
        if (type_of(h) == t_foreign) {
                HANDLE *ph = (HANDLE*)h->foreign.data;
                if (ph) CloseHandle(*ph);
        }
}

static cl_object
make_windows_handle(HANDLE h)
{
        cl_object foreign = ecl_allocate_foreign_data(@':pointer-void',
						      sizeof(HANDLE*));
        HANDLE *ph = (HANDLE*)foreign->foreign.data;
        *ph = h;
        si_set_finalizer(foreign, @'si::close-windows-handle');
        return foreign;
}
#endif

@(defun ext::external-process-wait (process_or_pid &optional (wait Cnil))
	cl_object status, code;
@
{
        if (type_of(process_or_pid) == T_STRUCTURE) {
                cl_object pid = cl_funcall(2, @'ext::external-process-pid',
                                           process_or_pid);
                if (Null(pid)) {
                        /* Process already exited */
                        return cl_funcall(2, @'ext::external-process-status',
                                          process_or_pid);
                }
                status = si_external_process_wait(2, pid, wait);
                code = VALUES(1);
                ecl_structure_set(process_or_pid, @'ext::external-process',
                                  0, Cnil);
                ecl_structure_set(process_or_pid, @'ext::external-process',
                                  3, status);
                ecl_structure_set(process_or_pid, @'ext::external-process',
                                  4, code);
        } else {
                cl_object exit_status = Cnil;
#if defined(ECL_MS_WINDOWS_HOST)
                HANDLE *hProcess = ecl_foreign_data_pointer_safe(process_or_pid);
                DWORD exitcode;
                int ok;
                WaitForSingleObject(*hProcess, Null(wait)? 0 : INFINITE);
                ecl_disable_interrupts_env(the_env);
                ok = GetExitCodeProcess(*hProcess, &exitcode);
                if (!ok) {
                        status = @':error';
                        code = Cnil;
                } else if (exitcode == STILL_ACTIVE) {
                        status = @':running';
                        code = Cnil;
                } else {
                        status = @':exited';
                        code = MAKE_FIXNUM(exitcode);
                        process_or_pid->foreign.data = NULL;
                        CloseHandle(*hProcess);
                }
                ecl_enable_interrupts_env(the_env);
#else
                cl_index pid = fixint(process_or_pid);
                int code_int;
                int error = waitpid(pid, &code_int, Null(wait)? WNOHANG : 0);
                if (error < 0) {
                        status = @':error';
                        code = Cnil;
                } else if (WIFEXITED(code_int)) {
                        status = @':exited';
                        code = MAKE_FIXNUM(WEXITSTATUS(code_int));
                } else if (WIFSIGNALED(code_int)) {
                        status = @':signaled';
                        code = MAKE_FIXNUM(WTERMSIG(code_int));
                } else if (WIFSTOPPED(code_int)) {
                        status = @':stopped';
                        code = MAKE_FIXNUM(WSTOPSIG(code_int));
                } else {
                        status = @':running';
                        code = Cnil;
                }
#endif
        }
        @(return status code)
}
@)

@(defun ext::run-program (command argv &key (input @':stream') (output @':stream')
	  		  (error @'t') (wait @'t') (environ Cnil)
                          (if_output_exists @':supersede'))
	int parent_write = 0, parent_read = 0;
	int child_pid;
	cl_object pid, process;
	cl_object stream_write;
	cl_object stream_read;
	cl_object exit_status = Cnil;
	cl_object external_process;
@
	command = si_copy_to_simple_base_string(command);
	argv = cl_mapcar(2, @'si::copy-to-simple-base-string', argv);
#if defined(ECL_MS_WINDOWS_HOST)
{
	BOOL ok;
	STARTUPINFO st_info;
	PROCESS_INFORMATION pr_info;
	HANDLE child_stdout, child_stdin, child_stderr;
	HANDLE current = GetCurrentProcess();
	HANDLE saved_stdout, saved_stdin, saved_stderr;
	SECURITY_ATTRIBUTES attr;
        cl_object env_buffer;
        char *env = NULL;

	/* Enclose each argument, as well as the file name
	   in double quotes, to avoid problems when these
	   arguments or file names have spaces */
	command =
		cl_format(4, Cnil,
			  ecl_make_simple_base_string("~S~{ ~S~}", -1),
			  command, argv);
	command = si_copy_to_simple_base_string(command);
	command = ecl_null_terminated_base_string(command);

        if (!Null(environ)) {
                env_buffer = from_list_to_execve_argument(environ, NULL);
                env = env_buffer->base_string.self;
        }

	attr.nLength = sizeof(SECURITY_ATTRIBUTES);
	attr.lpSecurityDescriptor = NULL;
	attr.bInheritHandle = TRUE;
 AGAIN_INPUT:
	if (input == @':stream') {
		/* Creates a pipe that we can read from what the child
		   writes to it. We duplicate one extreme of the pipe
		   so that the child does not inherit it. */
		HANDLE tmp;
		ok = CreatePipe(&child_stdin, &tmp, &attr, 0);
		if (ok) {
			ok = DuplicateHandle(current, tmp, current,
					     &tmp, 0, FALSE,
					     DUPLICATE_CLOSE_SOURCE |
					     DUPLICATE_SAME_ACCESS);
			if (ok) {
				parent_write = _open_osfhandle((intptr_t)tmp,
                                                               _O_WRONLY /*| _O_TEXT*/);
				if (parent_write < 0)
					printf("open_osfhandle failed\n");
			}
		}
	} else if (input == @'t') {
		/* The child inherits a duplicate of our input
		   handle. Creating a duplicate avoids problems when
		   the child closes it */
		input = ecl_symbol_value(@'*standard-input*');
                goto AGAIN_INPUT;
        } else if (Null(input)) {
		child_stdin = NULL;
		/*child_stdin = open("/dev/null", O_RDONLY);*/
        } else if (!Null(cl_streamp(input))) {
                /* If stream provides a handle, pass it to the child. Otherwise
                 * complain. */
		int stream_handle = ecl_stream_to_handle(input, 0);
		unlikely_if (stream_handle < 0) {
                        FEerror(":INPUT argument to RUN-PROGRAM does not "
                                "have a file handle:~%~S", 1, input);
                }
                DuplicateHandle(current,
                                (HANDLE)_get_osfhandle(stream_handle)
                                /*GetStdHandle(STD_INPUT_HANDLE)*/,
                                current, &child_stdin, 0, TRUE,
                                DUPLICATE_SAME_ACCESS);
	} else if (ECL_STRINGP(input) || ECL_PATHNAMEP(input)) {
                input = cl_open(5, input,
                                @':direction', @':input',
                                @':if-does-not-exist', @':error');
                goto AGAIN_INPUT;
	} else {
                FEerror("Invalid :INPUT argument to EXT:RUN-PROGRAM", 1,
                        input);
        }
 AGAIN_OUTPUT:
	if (output == @':stream') {
		/* Creates a pipe that we can write to and the
		   child reads from. We duplicate one extreme of the
		   pipe so that the child does not inherit it. */
		HANDLE tmp;
		ok = CreatePipe(&tmp, &child_stdout, &attr, 0);
		if (ok) {
			ok = DuplicateHandle(current, tmp, current,
					     &tmp, 0, FALSE,
					     DUPLICATE_CLOSE_SOURCE |
					     DUPLICATE_SAME_ACCESS);
			if (ok) {
				parent_read = _open_osfhandle((intptr_t)tmp,
                                                              _O_RDONLY /*| _O_TEXT*/);
				if (parent_read < 0)
					printf("open_osfhandle failed\n");
			}
		}
	} else if (output == @'t') {
		/* The child inherits a duplicate of our output
		   handle. Creating a duplicate avoids problems when
		   the child closes it */
		output = ecl_symbol_value(@'*standard-output*');
                goto AGAIN_OUTPUT;
        } else if (Null(output)) {
                child_stdout = NULL;
        } else if (ECL_STRINGP(output) || ECL_PATHNAMEP(output)) {
                output = cl_open(7, output,
                                 @':direction', @':output',
                                 @':if-exists', if_output_exists,
                                 @':if-does-not-exist', @':create');
                goto AGAIN_OUTPUT;
        } else if (!Null(cl_streamp(output))) {
		int stream_handle = ecl_stream_to_handle(output, 1);
                unlikely_if(stream_handle < 0) {
                        FEerror(":OUTPUT argument to RUN-PROGRAM does not "
                                "have a file handle:~%~S", 1, output);
                }
                DuplicateHandle(current,
                                (HANDLE)_get_osfhandle(stream_handle)
                                /*GetStdHandle(STD_OUTPUT_HANDLE)*/,
                                current, &child_stdout, 0, TRUE,
                                DUPLICATE_SAME_ACCESS);
	} else {
                FEerror("Invalid :OUTPUT argument to EXT:RUN-PROGRAM", 1,
                        output);
        }
 AGAIN_ERROR:
	if (error == @':output') {
		/* The child inherits a duplicate of its own output
		   handle.*/
		DuplicateHandle(current, child_stdout, current,
				&child_stderr, 0, TRUE,
				DUPLICATE_SAME_ACCESS);
	} else if (error == @'t') {
		/* The child inherits a duplicate of our output
		   handle. Creating a duplicate avoids problems when
		   the child closes it */
		error = ecl_symbol_value(@'*error-output*');
                goto AGAIN_ERROR;
        } else if (Null(error)) {
		child_stderr = NULL;
        } else if (!Null(cl_streamp(error))) {
		int stream_handle = ecl_stream_to_handle(error, 1);
		unlikely_if (stream_handle < 0) {
                        FEerror(":ERROR argument to RUN-PROGRAM does not "
                                "have a file handle:~%~S", 1, error);
                }
                DuplicateHandle(current,
                                (HANDLE)_get_osfhandle(stream_handle)
                                /*GetStdHandle(STD_ERROR_HANDLE)*/,
                                current, &child_stderr, 0, TRUE,
                                DUPLICATE_SAME_ACCESS);
	} else {
                FEerror("Invalid :ERROR argument to EXT:RUN-PROGRAM:~%~S", 1,
                        error);
	}
#if 1
	ZeroMemory(&st_info, sizeof(STARTUPINFO));
	st_info.cb = sizeof(STARTUPINFO);
	st_info.lpTitle = NULL; /* No window title, just exec name */
	st_info.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW; /* Specify std{in,out,err} */
	st_info.wShowWindow = SW_HIDE;
	st_info.hStdInput = child_stdin;
	st_info.hStdOutput = child_stdout;
	st_info.hStdError = child_stderr;
	ZeroMemory(&pr_info, sizeof(PROCESS_INFORMATION));
	ok = CreateProcess(NULL, command->base_string.self,
			   NULL, NULL, /* lpProcess/ThreadAttributes */
			   TRUE, /* Inherit handles (for files) */
			   /*CREATE_NEW_CONSOLE |*/
			   0 /*(input == Ct || output == Ct || error == Ct ? 0 : CREATE_NO_WINDOW)*/,
			   env, /* Inherit environment */
			   NULL, /* Current directory */
			   &st_info, /* Startup info */
			   &pr_info); /* Process info */
#else /* 1 */
	saved_stdin = GetStdHandle(STD_INPUT_HANDLE);
	saved_stdout = GetStdHandle(STD_OUTPUT_HANDLE);
	saved_stderr = GetStdHandle(STD_ERROR_HANDLE);
	SetStdHandle(STD_INPUT_HANDLE, child_stdin);
	SetStdHandle(STD_OUTPUT_HANDLE, child_stdout);
	SetStdHandle(STD_ERROR_HANDLE, child_stderr);
	ZeroMemory(&st_info, sizeof(STARTUPINFO));
	st_info.cb = sizeof(STARTUPINFO);
	ZeroMemory(&pr_info, sizeof(PROCESS_INFORMATION));
	ok = CreateProcess(NULL, command->base_string.self,
			   NULL, NULL, /* lpProcess/ThreadAttributes */
			   TRUE, /* Inherit handles (for files) */
			   /*CREATE_NEW_CONSOLE |*/
			   0,
			   NULL, /* Inherit environment */
			   NULL, /* Current directory */
			   &st_info, /* Startup info */
			   &pr_info); /* Process info */
	SetStdHandle(STD_INPUT_HANDLE, saved_stdin);
	SetStdHandle(STD_OUTPUT_HANDLE, saved_stdout);
	SetStdHandle(STD_ERROR_HANDLE, saved_stderr);
#endif /* 1 */
	/* Child handles must be closed in the parent process */
	/* otherwise the created pipes are never closed       */
	if (child_stdin) CloseHandle(child_stdin);
	if (child_stdout) CloseHandle(child_stdout);
	if (child_stderr) CloseHandle(child_stderr);
	if (ok) {
		CloseHandle(pr_info.hThread);
                pid = make_windows_handle(pr_info.hProcess);
	} else {
		char *message;
		FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM |
			      FORMAT_MESSAGE_ALLOCATE_BUFFER,
			      0, GetLastError(), 0, (void*)&message, 0, NULL);
		printf("%s\n", message);
		LocalFree(message);
		pid = Cnil;
	}
}
#else /* mingw */
{
	int child_stdin, child_stdout, child_stderr;
	argv = CONS(command, ecl_nconc(argv, ecl_list1(Cnil)));
	argv = cl_funcall(3, @'coerce', argv, @'vector');
 AGAIN_INPUT:
	if (input == @':stream') {
		int fd[2];
		pipe(fd);
		parent_write = fd[1];
		child_stdin = fd[0];
	} else if (input == @'t') {
                input = ecl_symbol_value(@'*standard-input*');
                goto AGAIN_INPUT;
        } else if (Null(input)) {
                child_stdin = open("/dev/null", O_RDONLY);
        } else if (!Null(cl_streamp(input))) {
                child_stdin = ecl_stream_to_handle(input, 0);
		if (child_stdin >= 0) {
			child_stdin = dup(child_stdin);
                } else {
                        FEerror(":INPUT argument to RUN-PROGRAM does not "
                                "have a file handle:~%~S", 1, input);
                }
	} else if (ECL_STRINGP(input) || ECL_PATHNAMEP(input)) {
                input = cl_open(5, input,
                                @':direction', @':input',
                                @':if-does-not-exist', @':error');
                goto AGAIN_INPUT;
	} else {
                FEerror("Invalid :INPUT argument to EXT:RUN-PROGRAM:~%~S", 1,
                        input);
        }
 AGAIN_OUTPUT:
	if (output == @':stream') {
		int fd[2];
		pipe(fd);
		parent_read = fd[0];
		child_stdout = fd[1];
	} else if (output == @'t') {
                output = ecl_symbol_value(@'*standard-output*');
                goto AGAIN_OUTPUT;
        } else if (Null(output)) {
                child_stdout = open("/dev/null", O_WRONLY);
        } else if (ECL_STRINGP(output) || ECL_PATHNAMEP(output)) {
                output = cl_open(7, output,
                                 @':direction', @':output',
                                 @':if-exists', if_output_exists,
                                 @':if-does-not-exist', @':create');
                goto AGAIN_OUTPUT;
        } else if (!Null(cl_streamp(output))) {
                child_stdout = ecl_stream_to_handle(output, 1);
		unlikely_if (child_stdout < 0) {
                        FEerror(":OUTPUT argument to RUN-PROGRAM does not "
                                "have a file handle:~%~S", 1, output);
                }
                child_stdout = dup(child_stdout);
	} else {
                FEerror("Invalid :OUTPUT argument to EXT:RUN-PROGRAM:~%~S", 1,
                        output);
        }
 AGAIN_ERROR:
	if (error == @':output') {
		child_stderr = child_stdout;
	} else if (error == @'t') {
		error = ecl_symbol_value(@'*error-output*');
                goto AGAIN_ERROR;
        } else if (!Null(cl_streamp(error))) {
		child_stderr = ecl_stream_to_handle(error, 1);
		unlikely_if (child_stderr < 0) {
                        FEerror(":ERROR argument to RUN-PROGRAM does not "
                                "have a file handle:~%~S", 1, error);
                }
		child_stderr = dup(child_stderr);
	} else if (Null(error)) {
                child_stderr = open("/dev/null", O_WRONLY);
        } else {
                FEerror("Invalid :ERROR argument to EXT:RUN-PROGRAM:~%~S", 1,
                        error);
	}
	child_pid = fork();
	if (child_pid == 0) {
		/* Child */
		int j;
		void **argv_ptr = (void **)argv->vector.self.t;
		close(0);
		dup(child_stdin);
		if (parent_write) close(parent_write);
		close(1);
		dup(child_stdout);
		if (parent_read) close(parent_read);
		close(2);
		dup(child_stderr);
		for (j = 0; j < argv->vector.fillp; j++) {
			cl_object arg = argv->vector.self.t[j];
			if (arg == Cnil) {
				argv_ptr[j] = NULL;
			} else {
				argv_ptr[j] = arg->base_string.self;
			}
		}
                if (!Null(environ)) {
                        char **pstrings;
                        cl_object buffer = from_list_to_execve_argument(environ,
                                                                        &pstrings);
                        execve((char*)command->base_string.self, argv_ptr, pstrings);
                } else {
                        execvp((char*)command->base_string.self, argv_ptr);
                }
		/* at this point exec has failed */
		perror("exec");
		abort();
	}
	close(child_stdin);
	close(child_stdout);
	close(child_stderr);
        if (child_pid < 0) {
                pid = Cnil;
        } else {
                pid = MAKE_FIXNUM(child_pid);
        }
}
#endif /* mingw */
	if (Null(pid)) {
		if (parent_write) close(parent_write);
		if (parent_read) close(parent_read);
		parent_write = 0;
		parent_read = 0;
		FEerror("Could not spawn subprocess to run ~S.", 1, command);
	}
	if (parent_write > 0) {
		stream_write = ecl_make_stream_from_fd(command, parent_write,
						       smm_output, 8,
						       ECL_STREAM_DEFAULT_FORMAT, Ct);
	} else {
		parent_write = 0;
		stream_write = cl_core.null_stream;
	}
	if (parent_read > 0) {
		stream_read = ecl_make_stream_from_fd(command, parent_read,
						      smm_input, 8,
						      ECL_STREAM_DEFAULT_FORMAT, Ct);
	} else {
		parent_read = 0;
		stream_read = cl_core.null_stream;
	}
	process = make_external_process(pid, stream_write, stream_read);
	if (!Null(wait)) {
                exit_status = si_external_process_wait(2, process, Ct);
                exit_status = VALUES(1);
        }
	@(return ((parent_read || parent_write)?
		  cl_make_two_way_stream(stream_read, stream_write) :
		  Cnil)
                 exit_status
                 process)
@)

