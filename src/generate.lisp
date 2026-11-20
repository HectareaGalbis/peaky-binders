
(in-package #:peaky-binders)

(defvar *bindings*)
(defvar *ignorable*)

(defun add-binding (var form)
  (push (list var form) *bindings*))

(defun add-temporary (name form)
  (let ((var (gensym name)))
    (push var *ignorable*)
    (add-binding var form)
    var))

(defun bind-pattern (pattern form)
  (if (pll-p pattern)
      (generate-bindings pattern form)
      (add-binding pattern form)))

(defun generate-bindings (pll form &key (whole #'identity) environment)
  (let ((list (add-temporary "LIST"
                             `(check-arguments ,form
                                               ',(pll-source pll)
                                               ,(length (pll-required pll))
                                               ,(length (pll-optional pll))
                                               ,(and (pll-rest pll) t)
                                               ,(pll-keyp pll)
                                               ',(mapcar #'first (pll-keys pll))
                                               ,(pll-allow-other-keys pll)))))
    (when (pll-whole pll)
      (add-binding (pll-whole pll) (funcall whole list)))
    (when (pll-environmentp pll)
      (add-binding (pll-environment pll) environment))
    (let ((tail list))
      (dolist (pattern (pll-required pll))
        (bind-pattern pattern `(car ,tail))
        (setf tail (add-temporary "TAIL" `(cdr ,tail))))
      (dolist (spec (pll-optional pll))
        (destructuring-bind (pattern init svar) spec
          (let ((suppliedp (add-temporary "SUPPLIEDP" `(consp ,tail))))
            (bind-pattern pattern `(if ,suppliedp (car ,tail) ,init))
            (when svar
              (add-binding svar suppliedp))
            (setf tail (add-temporary "TAIL" `(if ,suppliedp (cdr ,tail) ,tail))))))
      (when (pll-rest pll)
        (bind-pattern (pll-rest pll) tail))
      (dolist (spec (pll-keys pll))
        (destructuring-bind (keyword pattern init svar) spec
          (let ((found (add-temporary "KEY"
                                      `(nth-value 2 (get-properties ,tail '(,keyword))))))
            (bind-pattern pattern `(if ,found (cadr ,found) ,init))
            (when svar
              (add-binding svar `(if ,found t nil))))))
      (dolist (spec (pll-aux pll))
        (add-binding (first spec) (second spec))))))

(defun make-bind-form (pll form body &rest options)
  (let ((*bindings* '())
        (*ignorable* '()))
    (apply #'generate-bindings pll form options)
    `(let* ,(reverse *bindings*)
       (declare (ignorable ,@(reverse *ignorable*)))
       ,@body)))

(defun ordinary-bind-form (lambda-list arguments body)
  "Return a form that evaluates the form ARGUMENTS, which must produce a list,
binds the variables of the ordinary LAMBDA-LIST as if the list were the
arguments of a function call and evaluates the forms in the list BODY.
Declarations at the beginning of BODY affect the variables of LAMBDA-LIST.

A LAMBDA-LIST-ERROR is signaled if LAMBDA-LIST is malformed. The returned form
signals a BINDING-ERROR if the list does not match LAMBDA-LIST."
  (make-bind-form (parse-lambda-list lambda-list :ordinary) arguments body))

(defun destructuring-bind-form (lambda-list expression body)
  "Return a form that evaluates the form EXPRESSION, destructures its value
with the destructuring LAMBDA-LIST and evaluates the forms in the list BODY.
Declarations at the beginning of BODY affect the variables of LAMBDA-LIST.

A LAMBDA-LIST-ERROR is signaled if LAMBDA-LIST is malformed. The returned form
signals a BINDING-ERROR if the value does not match LAMBDA-LIST."
  (make-bind-form (parse-lambda-list lambda-list :destructuring) expression body))

(defun macro-bind-form (lambda-list arguments body &key name environment)
  "Return a form that evaluates the form ARGUMENTS, which must produce the
list of arguments of a macro call (without the operator), binds the variables
of the macro LAMBDA-LIST and evaluates the forms in the list BODY.
Declarations at the beginning of BODY affect the variables of LAMBDA-LIST.

NAME and ENVIRONMENT are forms inserted into the returned form. The &whole
variable is bound to (NAME . arguments) and the &environment variable is bound
to the value of ENVIRONMENT. Both default to NIL.

A LAMBDA-LIST-ERROR is signaled if LAMBDA-LIST is malformed. The returned form
signals a BINDING-ERROR if the arguments do not match LAMBDA-LIST."
  (make-bind-form (parse-lambda-list lambda-list :macro) arguments body
                  :whole (lambda (list) `(cons ,name ,list))
                  :environment environment))
