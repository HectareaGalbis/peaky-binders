
(in-package #:peaky-binders)

(defmacro ordinary-bind (lambda-list arguments &body body)
  "Evaluate ARGUMENTS, which must produce a list, bind the variables of the
ordinary LAMBDA-LIST as if the list were the arguments of a function call and
evaluate BODY. Declarations at the beginning of BODY affect the variables of
LAMBDA-LIST.

A LAMBDA-LIST-ERROR is signaled at macroexpansion time if LAMBDA-LIST is
malformed. A BINDING-ERROR is signaled at run time if the list does not match
LAMBDA-LIST."
  (ordinary-bind-form lambda-list arguments body))

(defmacro macro-bind ((lambda-list &key name environment) arguments &body body)
  "Evaluate ARGUMENTS, which must produce the list of arguments of a macro
call (without the operator), bind the variables of the macro LAMBDA-LIST and
evaluate BODY. Declarations at the beginning of BODY affect the variables of
LAMBDA-LIST.

NAME and ENVIRONMENT are evaluated and default to NIL. The &whole variable is
bound to (NAME . arguments) and the &environment variable is bound to the
value of ENVIRONMENT.

A LAMBDA-LIST-ERROR is signaled at macroexpansion time if LAMBDA-LIST is
malformed. A BINDING-ERROR is signaled at run time if the arguments do not
match LAMBDA-LIST."
  (macro-bind-form lambda-list arguments body :name name :environment environment))
