;;;;  -*- Mode: Lisp; Syntax: Common-Lisp; Package: C -*-
;;;;
;;;;  Copyright (c) 1984, Taiichi Yuasa and Masami Hagiya.
;;;;  Copyright (c) 1990, Giuseppe Attardi.
;;;;
;;;;    This program is free software; you can redistribute it and/or
;;;;    modify it under the terms of the GNU Library General Public
;;;;    License as published by the Free Software Foundation; either
;;;;    version 2 of the License, or (at your option) any later version.
;;;;
;;;;    See file '../Copyright' for full details.

;;;; CMPVAR  Variables.

(in-package "COMPILER")

(defun make-var (&rest args)
  (let ((var (apply #'%make-var args)))
    (unless (member (var-kind var) '(SPECIAL GLOBAL))
      (when *current-function*
	(push var (fun-local-vars *current-function*))))
    var))

(defun var-referenced-in-form-list (var form-list)
  (loop for f in form-list
     thereis (var-referenced-in-form var f)))

(defun var-changed-in-form-list (var form-list)
  (loop for f in form-list
     thereis (var-changed-in-form var f)))

;;; FIXME! VAR-REFERENCED-IN-FORM and VAR-CHANGED-IN-FORM are too
;;; pessimistic. One should check whether the functions reading/setting the
;;; variable are actually called from the given node.  The problem arises when
;;; we create a closure of a function, as in
;;;
;;;	(let* ((a 1) (b #'(lambda () (incf a)))) ...)
;;;
;;; To know whether A is changed or read, we would have to track where B is
;;; actually used.

(defun var-referenced-in-form (var form)
  (declare (type var var))
  (or (find-form-in-node-list form (var-read-nodes var))
      (var-functions-reading var)))

(defun var-changed-in-form (var form)
  (declare (type var var))
  (or (find-form-in-node-list form (var-set-nodes var))
      (let ((kind (var-kind var)))
	(if (or (eq kind 'SPECIAL) (eq kind 'GLOBAL))
	    (c1form-sp-change form)
	    (var-functions-setting var)))))

(defun update-variable-type (var orig-type)
  ;; FIXME! Refuse to update type of variables that are modified
  (when (var-set-nodes var)
    (return-from update-variable-type))
  (let ((type (type-and (var-type var) orig-type)))
    (if (null type)
	(cmpwarn "Variable assigned a value incompatible with its type declaration.~%Variable: ~A~%Expected type: ~A~%Value type: ~A"
		 (var-name var)
		 (var-type var)
		 orig-type)
	(loop for form in (var-read-forms var)
	   when (and (eq (c1form-name form) 'VAR)
		     (eq var (c1form-arg 0 form)))
	   do (setf (c1form-type form) (type-and type (c1form-primary-type form)))
	   finally (setf (var-type var) type)))))

(defun var-read-forms (var)
  (mapcar #'first (var-read-nodes var)))

(defun assert-var-ref-value (var)
  (unless (let ((ref (var-ref var)))
	    (or (> ref (/ most-positive-fixnum 2))
		(= (var-ref var) (+ (length (var-read-nodes var))
				    (length (var-set-nodes var))))))
    (baboon :format-control "Number of references in VAR ~A unequal to references list"
	    :format-arguments (list var))))

(defun assert-var-not-ignored (var)
  (when (let ((x (var-ignorable var))) (and x (minusp x)))
    (cmpwarn "Variable ~A, declared as IGNORE, found in a lisp form."
	     (var-name var))
    (setf (var-ignorable var) nil)))

(defun delete-from-read-nodes (var form)
  (assert-var-ref-value var)
  (setf (var-ref var) (1- (var-ref var))
	(var-read-nodes var) (delete-form-from-node-list form (var-read-nodes var))))

(defun add-to-read-nodes (var form)
  (assert-var-ref-value var)
  (assert-var-not-ignored var)
  (setf (var-ref var) (1+ (var-ref var))
	(var-read-nodes var) (add-form-to-node-list form (var-read-nodes var)))
  (when *current-function*
    (unless (eq *current-function* (var-function var))
      (pushnew *current-function* (var-functions-reading var))
      (pushnew var (fun-referred-vars *current-function*))))
  form)

(defun add-to-set-nodes (var form)
  (assert-var-ref-value var)
  (assert-var-not-ignored var)
  (setf (var-ref var) (1+ (var-ref var))
	(var-set-nodes var) (add-form-to-node-list form (var-set-nodes var)))
  ;;(push form (var-read-nodes var))
  (when *current-function*
    (unless (eq *current-function* (var-function var))
      (pushnew *current-function* (var-functions-setting var))
      (pushnew var (fun-referred-vars *current-function*))))
  form)

(defun add-to-set-nodes-of-var-list (var-list form)
  (dolist (v var-list)
    (add-to-set-nodes v form))
  form)

;;; A special binding creates a var object with the kind field SPECIAL,
;;; whereas a special declaration without binding creates a var object with
;;; the kind field GLOBAL.  Thus a reference to GLOBAL may need to make sure
;;; that the variable has a value.

;;;  Bootstrap problem: proclaim needs this function:
(defun sch-global (name)
  (dolist (var *undefined-vars*)
    (declare (type var var))
    (when (eq (var-name var) name)
      (return-from sch-global var))))

;;;
;;; Check if a variable has been declared as a special variable with a global
;;; value.

(defun check-global (name)
  (member name *global-vars* :test #'eq :key #'var-name))

(defun special-variable-p (name)
  "Return true if NAME is associated to a special variable in the lexical environment."
  (or (si::specialp name)
      (check-global name)
      (let ((v (cmp-env-search-var name *cmp-env-root*)))
        ;; Fixme! Revise the declamation code to ensure whether
        ;; we also have to consider 'GLOBAL here.
        (and v (eq (var-kind v) 'SPECIAL)))))

(defun local-variable-p (name &optional (env *cmp-env*))
  (let ((record (cmp-env-search-var name env)))
    (and record (var-p record))))

(defun symbol-macro-p (name &optional (env *cmp-env*))
  (let ((record (cmp-env-search-var name env)))
    (and record (not (var-p record)))))

;;;
;;; Check if the symbol has a symbol macro
;;;
(defun chk-symbol-macrolet (form)
  (loop
   (when (not (symbolp form))
     (return form))
   (let ((new-form (macroexpand-1 form *cmp-env*)))
     (when (eq new-form form)
       (return form))
     (setf form new-form))))

(defun c1make-var (name specials ignores types)
  (cmpck (not (symbolp name)) "The variable ~s is not a symbol." name)
  (cmpck (constantp name) "The constant ~s is being bound." name)
  (let ((ignorable (cdr (assoc name ignores)))
        type)
    (setq type (if (setq type (assoc name types))
                   (cdr type)
                   'T))
    (cond ((or (member name specials) (special-variable-p name))
           (unless type
	     (setf type (or (get-sysprop name 'CMP-TYPE) 'T)))
	   (c1make-global-variable name :kind 'SPECIAL :type type))
          (t
	   (make-var :name name :type type :loc 'OBJECT
		     :kind 'LEXICAL ; we rely on check-vref to fix it
                     :ignorable ignorable
		     :ref 0)))))

(defun check-vref (var)
  (when (eq (var-kind var) 'LEXICAL)
    (when (and (zerop (var-ref var)) ;;; This field may be -1 (IGNORE). Beppe
               (not (var-ignorable var)))
        (cmpwarn "The variable ~s is not used." (var-name var)))
    (when (not (var-ref-clb var))
      ;; if the variable can be stored locally, set it var-kind to its type
      (setf (var-kind var)
	    (if (plusp (var-ref var))
		(lisp-type->rep-type (var-type var))
		:OBJECT)))))

(defun c1var (name)
  (let* ((var (c1vref name))
	 (output (make-c1form* 'VAR
			       :type (var-type var)
			       :args var)))
      (add-to-read-nodes var output)
      output))

(defun make-lcl-var (&key rep-type (type 'T))
  (unless rep-type
    (setq rep-type (if type (lisp-type->rep-type type) :object)))
  (unless type
    (setq type 'T))
  (make-var :kind rep-type :type type :loc (next-lcl)))

(defun make-temp-var (&optional (type 'T))
  (make-var :kind :object :type type :loc `(TEMP ,(next-temp))))

;;; A variable reference (vref for short) is a list: pair
;;;	( var-object ) Beppe(ccb) ccb-reference )

(defun c1vref (name)
  (multiple-value-bind (var ccb clb unw)
      (cmp-env-search-var name)
    (cond ((null var)
	   (c1make-global-variable name :warn t
				   :type (or (get-sysprop name 'CMP-TYPE) t)))
	  ((not (var-p var))
	   ;; symbol-macrolet
	   (baboon))
	  (t
	   (assert-var-ref-value var)
	   (assert-var-not-ignored var)
	   (when (eq (var-kind var) 'LEXICAL)
	     (cond (ccb (setf (var-ref-clb var) nil ; replace a previous 'CLB
			      (var-ref-ccb var) t
			      (var-kind var) 'CLOSURE
			      (var-loc var) 'OBJECT))
		   (clb (setf (var-ref-clb var) t
			      (var-loc var) 'OBJECT))))
	   var))))

(defun push-vars (v)
  (setf (var-index v) (length (cmp-env-variables)))
  (cmp-env-register-var v))

(defun unboxed (var)
  (not (eq (var-rep-type var) :object)))

(defun local (var)
  (and (not (member (var-kind var) '(LEXICAL CLOSURE SPECIAL GLOBAL)))
       (var-kind var)))

(defun global-var-p (var)
  (let ((kind (var-kind var)))
    (or (eq kind 'global)
        (eq kind 'special))))

(defun c2var (vref) (unwind-exit vref))

(defun c2location (loc) (unwind-exit loc))

(defun wt-var (var &aux (var-loc (var-loc var))) ; ccb
  (declare (type var var))
  (case (var-kind var)
    (CLOSURE (wt-env var-loc))
    (LEXICAL (wt-lex var-loc))
    ((SPECIAL GLOBAL)
     (if (safe-compile)
	 (wt "ecl_symbol_value(" var-loc ")")
	 (wt "ECL_SYM_VAL(cl_env_copy," var-loc ")")))
    (t (wt var-loc))
    ))

(defun var-rep-type (var)
  (case (var-kind var)
    ((LEXICAL CLOSURE SPECIAL GLOBAL) :object)
    (t (var-kind var))))

(defun set-var (loc var &aux (var-loc (var-loc var))) ;  ccb
  (if (var-p var)
    (case (var-kind var)
      (CLOSURE
       (wt-nl)(wt-env var-loc)(wt "= ")
       (wt-coerce-loc (var-rep-type var) loc)
       (wt #\;))
      (LEXICAL
       (wt-nl)(wt-lex var-loc)(wt "= ")
       (wt-coerce-loc (var-rep-type var) loc)
       (wt #\;))
      ((SPECIAL GLOBAL)
       (if (safe-compile)
	   (wt-nl "cl_set(" var-loc ",")
	   (wt-nl "ECL_SETQ(cl_env_copy," var-loc ","))
       (wt-coerce-loc (var-rep-type var) loc)
       (wt ");"))
      (t
       (wt-nl var-loc "= ")
       (wt-coerce-loc (var-rep-type var) loc)
       (wt #\;))
    )
    (baboon)))

(defun wt-lex (lex)
  (if (consp lex)
    (wt "lex" (car lex) "[" (cdr lex) "]")
    (wt-lcl lex)))

;;; reference to variable of inner closure.
(defun wt-env (clv) (wt "ECL_CONS_CAR(CLV" clv ")"))

;;; ----------------------------------------------------------------------

(defun c1make-global-variable (name &key (type t) (kind 'GLOBAL) (warn nil))
  (let ((var (find name *global-var-objects* :key #'var-name)))
    (unless var
      (setf var (make-var :name name :kind kind :type type :loc (add-symbol name))))
    (push var *global-var-objects*)
    (when warn
      (unless (or (constantp name) (special-variable-p name))
	(undefined-variable name)
	(push var *undefined-vars*)))
    var))

(defun c1declare-specials (globals)
  (mapc #'cmp-env-declare-special globals))

(defun si::register-global (name)
  (unless (check-global name)
    (push (c1make-global-variable name :kind 'GLOBAL
				  :type (or (get-sysprop name 'CMP-TYPE) 'T))
	  *global-vars*))
  (values))

(defun c1setq (args)
  (let ((l (length args)))
    (declare (fixnum l))
    (cmpck (oddp l) "SETQ requires an even number of arguments.")
    (cond ((zerop l) (c1nil))
	  ((= l 2) (c1setq1 (first args) (second args)))
	  (t
	   (do ((pairs args (cddr pairs))
		(forms nil))
	       ((endp pairs)
		(make-c1form* 'PROGN
			      :type (c1form-type (first forms))
			      :args (nreverse forms)))
             (push (c1setq1 (first pairs) (second pairs)) forms)
             )))))

(defun c1setq1 (name form)
  (cmpck (not (symbolp name)) "The variable ~s is not a symbol." name)
  (cmpck (constantp name) "The constant ~s is being assigned a value." name)
  (setq name (chk-symbol-macrolet name))
  (if (symbolp name)
      (let* ((name (c1vref name))
	     (type (var-type name))
	     (form (c1expr (if (trivial-type-p type)
			       form
			       `(checked-value ,form ,type)))))
	(add-to-set-nodes name (make-c1form* 'SETQ
					     :type (c1form-type form)
					     :args name form)))
      `(setf name ,form)))

(defun c2setq (vref form)
  (let ((*destination* vref)) (c2expr* form))
  (if (eq (c1form-name form) 'LOCATION)
    (c2location (c1form-arg 0 form))
    (unwind-exit vref))
  )

(defun c1progv (args)
  (check-args-number 'PROGV args 2)
  (let ((symbols (c1expr (first args)))
	(values (c1expr (second args)))
	(forms (c1progn (cddr args))))
    (make-c1form* 'PROGV :type (c1form-type forms)
		  :args symbols values forms)))

(defun c2progv (symbols values body)
  (let* ((*lcl* *lcl*)
         (lcl (next-lcl))
         (sym-loc (make-lcl-var))
         (val-loc (make-lcl-var))
         (*unwind-exit* (cons lcl *unwind-exit*)))
    (wt-nl "{cl_object " sym-loc "," val-loc "; cl_index " lcl ";")
    (let ((*destination* sym-loc)) (c2expr* symbols))
    (let ((*destination* val-loc)) (c2expr* values))
    (wt-nl lcl "= ecl_progv(cl_env_copy," sym-loc "," val-loc ");")
    (c2expr body)
    (wt "}")
    ))

(defun c1psetq (old-args &aux (args nil) (use-psetf nil))
  (do (var (l old-args (cddr l)))
      ((endp l))
      (declare (object l))
      (setq var (car l))
      (cmpck (not (symbolp var))
             "The variable ~s is not a symbol." var)
      (cmpck (endp (cdr l))
             "No form was given for the value of ~s." var)
      (setq var (chk-symbol-macrolet var))
      (setq args (nconc args (list var (second l))))
      (if (symbolp var)
	(cmpck (constantp var)
	       "The constant ~s is being assigned a value." var)
	(setq use-psetf t)))
  (when use-psetf
    (return-from c1psetq `(psetf ,@args)))
  (do ((l args (cddr l))
       (vrefs '())
       (forms '()))
      ((endp l)
       (add-to-set-nodes-of-var-list
	vrefs (make-c1form* 'PSETQ :type '(MEMBER NIL)
			    :args (reverse vrefs) (nreverse forms))))
    (let* ((vref (c1vref (first l)))
	   (form (c1expr (second l)))
	   (type (type-and (var-type vref) (c1form-primary-type form))))
      (unless type
	(cmpwarn "Type mismatch between ~s and ~s." (var-name vref) form)
	(setq type T))
	;; Is this justified????
	#+nil(setf (c1form-type form) type)
	(push vref vrefs)
	(push form forms))))

(defun c2psetq (vrefs forms &aux (*lcl* *lcl*) (saves nil) (blocks 0))
  ;; similar to inline-args
  (do ((vrefs vrefs (cdr vrefs))
       (forms forms (cdr forms))
       (var) (form))
      ((null vrefs))
    (setq var (first vrefs)
	  form (car forms))
    (if (or (var-changed-in-form-list var (rest forms))
	    (var-referenced-in-form-list var (rest forms)))
        (case (c1form-name form)
          (LOCATION (push (cons var (c1form-arg 0 form)) saves))
          (otherwise
            (if (local var)
                (let* ((rep-type (var-rep-type var))
		       (rep-type-name (rep-type-name rep-type))
		       (temp (make-lcl-var :rep-type rep-type)))
                  (wt-nl "{" *volatile* rep-type-name " " temp ";")
                  (incf blocks)
                  (let ((*destination* temp)) (c2expr* form))
                  (push (cons var temp) saves))
                (let ((*destination* (make-temp-var)))
                  (c2expr* form)
                  (push (cons var *destination*) saves)))))
        (let ((*destination* var)) (c2expr* form))))
  (dolist (save saves) (set-var (cdr save) (car save)))
  (dotimes (i blocks) (wt "}"))
  (unwind-exit nil)
  )
