;;;;  -*- Mode: Lisp; Syntax: Common-Lisp; Package: C -*-
;;;;
;;;;  CMPFUN  Library functions.

;;;;  Copyright (c) 1984, Taiichi Yuasa and Masami Hagiya.
;;;;  Copyright (c) 1990, Giuseppe Attardi and William F. Schelter.
;;;;
;;;;    This program is free software; you can redistribute it and/or
;;;;    modify it under the terms of the GNU Library General Public
;;;;    License as published by the Free Software Foundation; either
;;;;    version 2 of the License, or (at your option) any later version.
;;;;
;;;;    See file '../Copyright' for full details.


(in-package "COMPILER")

(defvar *princ-string-limit* 80)

(defun c1princ (args)
  (check-args-number 'PRINC args 1 2)
  (let ((object (first args))
	(stream (if (endp (rest args))
		    (c1nil)
		    (c1expr (second args)))))
    (if (and (or (and (stringp object)
		      (<= (length object) *princ-string-limit*))
		 (characterp object))
	     (or (endp (rest args))
		 (eq (c1form-name stream) 'VAR)))
	(make-c1form* 'C2PRINC :args object (c1form-arg 0 stream) stream)
	(c1call-global 'PRINC args))))

(defun c2princ (string stream-var stream)
  (cond ((eq *destination* 'TRASH)
	 (cond ((characterp string)
		(wt-nl "ecl_princ_char(" (char-code string) "," stream-var ");"))
	       ((= (length string) 1)
		(wt-nl "ecl_princ_char(" (char-code (aref string 0)) ","
		       stream-var ");"))
	       (t
		(wt-nl "ecl_princ_str(\"")
		(dotimes (n (length string))
		  (declare (fixnum n))
		  (let ((char (schar string n)))
		       (cond ((char= char #\\) (wt "\\\\"))
			     ((char= char #\") (wt "\\\""))
			     ((char= char #\Newline) (wt "\\n"))
			     (t (wt char)))))
		(wt "\"," stream-var ");")))
	 (unwind-exit nil))
	((eql string #\Newline) (c2call-global 'TERPRI (list stream) t))
	(t (c2call-global 'PRINC
                          (list (make-c1form 'LOCATION *info* (add-object string))
                                stream)
                          t))))

(defun c1terpri (args &aux stream)
  (check-args-number 'TERPRI args 0 1)
  (setq stream (if (endp args)
		   (c1nil)
		   (c1expr (first args))))
  (if (or (endp args)
	  (and (eq (c1form-name stream) 'VAR)
	       (member (var-kind (c1form-arg 0 stream)) '(GLOBAL SPECIAL))))
      (make-c1form* 'C2PRINC :args  #\Newline
		    (if (endp args) nil (c1form-arg 0 stream))
		    stream)
      (c1call-global 'TERPRI args)))

(defun c1apply (args)
  (check-args-number 'APPLY args 2)
  (let* ((fun (first args))
	 (arguments (rest args)))
    (cond ((and (consp fun)
		(eq (first fun) 'LAMBDA))
	   (c1expr (optimize-funcall/apply-lambda (cdr fun) arguments t)))
	  ((and (consp fun)
		(eq (first fun) 'EXT::LAMBDA-BLOCK))
	   (setf fun (macroexpand-1 fun))
	   (c1expr (optimize-funcall/apply-lambda (cdr fun) arguments t)))
	  ((and (consp fun)
		(eq (first fun) 'FUNCTION)
		(consp (second fun))
		(member (caadr fun) '(LAMBDA EXT::LAMBDA-BLOCK)))
	   (c1apply (list* (second fun) arguments)))
	  (t
	   (c1funcall (list* '#'APPLY args))))))

(defun c1rplacd (args)
  (check-args-number 'RPLACD args 2 2)
  (make-c1form* 'RPLACD :args (c1args* args)))

(defun c2rplacd (args)
  (let* ((*inline-blocks* 0)
         (*temp* *temp*)
         (args (coerce-locs (inline-args args)))
         (x (first args))
         (y (second args)))
    (when (safe-compile)
      (wt-nl "if (ecl_unlikely(ATOM(" x ")))"
             "FEtype_error_cons(" x ");"))
    (wt-nl "ECL_CONS_CDR(" x ") = " y ";")
    (unwind-exit x)
    (close-inline-blocks)))

;;----------------------------------------------------------------------
;; We transform BOOLE into the individual operations, which have
;; inliners
;;

(define-compiler-macro boole (&whole form op-code op1 op2)
  (or (and (constantp op-code)
	   (case (eval op-code)
	     (#. boole-clr `(progn ,op1 ,op2 0))
	     (#. boole-set `(progn ,op1 ,op2 -1))
	     (#. boole-1 `(prog1 ,op1 ,op2))
	     (#. boole-2 `(progn ,op1 ,op2))
	     (#. boole-c1 `(prog1 (lognot ,op1) ,op2))
	     (#. boole-c2 `(progn ,op1 (lognot ,op2)))
	     (#. boole-and `(logand ,op1 ,op2))
	     (#. boole-ior `(logior ,op1 ,op2))
	     (#. boole-xor `(logxor ,op1 ,op2))
	     (#. boole-eqv `(logeqv ,op1 ,op2))
	     (#. boole-nand `(lognand ,op1 ,op2))
	     (#. boole-nor `(lognor ,op1 ,op2))
	     (#. boole-andc1 `(logandc1 ,op1 ,op2))
	     (#. boole-andc2 `(logandc2 ,op1 ,op2))
	     (#. boole-orc1 `(logorc1 ,op1 ,op2))
	     (#. boole-orc2 `(logorc2 ,op1 ,op2))))
      form))

;----------------------------------------------------------------------

;; Return the most particular type we can EASILY obtain from x.  
(defun result-type (x)
  (cond ((symbolp x)
	 (c1form-primary-type (c1expr x)))
	((constantp x)
	 (type-of x))
	((and (consp x) (eq (car x) 'the))
	 (second x))
	(t t)))

