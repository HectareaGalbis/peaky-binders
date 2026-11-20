

<a id="TITLE:ADP-GITHUB-WRITING:TAG1"></a>
# Peaky Binders

Welcome to Peaky Binders\!

This library defines functions that return the code needed to bind the variables of a lambda list\. They are meant to write macros like ```destructuring-bind```\, but they support three kinds of lambda lists\:

* Ordinary lambda lists\.
* Destructuring lambda lists\.
* Macro lambda lists\, where you can choose the macro name used by ```&whole```\.


Every symbol is exported from the ```peaky-binders``` package\, although you can use the nickname ```pbinders```\.

* [Installation](/README.md#TITLE:ADP-GITHUB-WRITING:TAG2)
* [Binding macros](/README.md#TITLE:ADP-GITHUB-WRITING:TAG3)
  * [ordinary\-bind](/README.md#TITLE:ADP-GITHUB-WRITING:TAG4)
  * [destructuring\-bind](/README.md#TITLE:ADP-GITHUB-WRITING:TAG5)
  * [macro\-bind](/README.md#TITLE:ADP-GITHUB-WRITING:TAG6)
* [Writing your own macros](/README.md#TITLE:ADP-GITHUB-WRITING:TAG7)
* [Lambda lists](/README.md#TITLE:ADP-GITHUB-WRITING:TAG8)
* [Errors](/README.md#TITLE:ADP-GITHUB-WRITING:TAG9)
  * [lambda\-list\-error](/README.md#TITLE:ADP-GITHUB-WRITING:TAG10)
  * [binding\-error](/README.md#TITLE:ADP-GITHUB-WRITING:TAG11)
* [Reference](/README.md#TITLE:ADP-GITHUB-WRITING:TAG12)



<a id="TITLE:ADP-GITHUB-WRITING:TAG2"></a>
## Installation

Clone the repository into a directory where ASDF can find it\:

`````sh
cd ~/common-lisp
git clone https://github.com/HectareaGalbis/peaky-binders.git
`````

And load it\:

`````common-lisp
(asdf:load-system "peaky-binders")
`````


<a id="TITLE:ADP-GITHUB-WRITING:TAG3"></a>
## Binding macros

The library defines two macros\, ```ordinary-bind``` and ```macro-bind```\, and re\-exports ```cl:destructuring-bind```\, so the three kinds of lambda lists can be used from the same package\.

<a id="TITLE:ADP-GITHUB-WRITING:TAG4"></a>
### ordinary\-bind

`````common-lisp
(ordinary-bind lambda-list arguments &body body)
`````

Evaluates ```arguments```\, which must produce a list\, and binds the variables of the ordinary ```lambda-list``` as if the list were the arguments of a function call\. Then\, ```body``` is evaluated\.

`````common-lisp
(ordinary-bind (a &optional (b (* a 10)) &rest r &key c) (list 1 2 :c 3)
  (list a b r c))
`````
`````common-lisp
;; Returns
(1 2 (:C 3) 3)
`````

`````common-lisp
(ordinary-bind (a &optional (b (* a 10) bp)) (list 1)
  (list a b bp))
`````
`````common-lisp
;; Returns
(1 10 NIL)
`````

Declarations at the beginning of ```body``` affect the variables of the lambda list\:

`````common-lisp
(ordinary-bind (a b) (list 1 2)
  (declare (fixnum a b))
  (+ a b))
`````
`````common-lisp
;; Returns
3
`````

<a id="TITLE:ADP-GITHUB-WRITING:TAG5"></a>
### destructuring\-bind

It is the same symbol as ```cl:destructuring-bind```\.

`````common-lisp
(eq 'peaky-binders:destructuring-bind 'cl:destructuring-bind)
`````
`````common-lisp
;; Returns
T
`````

<a id="TITLE:ADP-GITHUB-WRITING:TAG6"></a>
### macro\-bind

`````common-lisp
(macro-bind (lambda-list &key name environment) arguments &body body)
`````

Evaluates ```arguments```\, which must produce the list of arguments of a macro call \(without the operator\)\, binds the variables of the macro ```lambda-list``` and evaluates ```body```\.

* The ```&whole``` variable is bound to a list whose ```car``` is the value of ```name``` and whose ```cdr``` is the list of arguments\.
* The ```&environment``` variable is bound to the value of ```environment```\.


Both ```name``` and ```environment``` are evaluated\. They default to ```nil```\.

`````common-lisp
(macro-bind ((&whole w (a b) &body body) :name 'my-macro) '((1 2) x y)
  (list w a b body))
`````
`````common-lisp
;; Returns
((MY-MACRO (1 2) X Y) 1 2 (X Y))
`````

`````common-lisp
(macro-bind ((&environment env a) :environment :some-environment) '(1)
  (list env a))
`````
`````common-lisp
;; Returns
(:SOME-ENVIRONMENT 1)
`````


<a id="TITLE:ADP-GITHUB-WRITING:TAG7"></a>
## Writing your own macros

The macros above are built with the following functions\. They receive a lambda list\, a form and a list of body forms\, and return a form that evaluates the given form\, binds the variables of the lambda list and evaluates the body forms\.

`````common-lisp
(ordinary-bind-form lambda-list arguments body)
(destructuring-bind-form lambda-list expression body)
(macro-bind-form lambda-list arguments body &key name environment)
`````

In ```macro-bind-form```\, ```name``` and ```environment``` are forms that are inserted into the generated code\.

`````common-lisp
(destructuring-bind-form '(a (b c)) 'expression '((list a b c)))
`````
`````common-lisp
;; Returns
(LET* ((#:LIST187
        (PEAKY-BINDERS::CHECK-ARGUMENTS EXPRESSION '(A (B C)) 2 0 NIL NIL 'NIL
                                        NIL))
       (A (CAR #:LIST187))
       (#:TAIL188 (CDR #:LIST187))
       (#:LIST189
        (PEAKY-BINDERS::CHECK-ARGUMENTS (CAR #:TAIL188) '(B C) 2 0 NIL NIL 'NIL
                                        NIL))
       (B (CAR #:LIST189))
       (#:TAIL190 (CDR #:LIST189))
       (C (CAR #:TAIL190))
       (#:TAIL191 (CDR #:TAIL190))
       (#:TAIL192 (CDR #:TAIL188)))
  (DECLARE
   (IGNORABLE #:LIST187 #:TAIL188 #:LIST189 #:TAIL190 #:TAIL191 #:TAIL192))
  (LIST A B C))
`````

For example\, this is a version of ```defmacro``` that uses ```macro-bind-form```\:

`````common-lisp
(defmacro my-defmacro (name lambda-list &body body)
  (let ((form (gensym "FORM"))
        (env (gensym "ENV"))
        (ignored (gensym "IGNORED")))
    `(defmacro ,name (&whole ,form &environment ,env &rest ,ignored)
       (declare (ignore ,ignored) (ignorable ,env))
       ,(macro-bind-form lambda-list `(cdr ,form) body
                         :name `',name
                         :environment env))))

(my-defmacro show (&whole whole &environment env form)
  `'(,whole ,(macroexpand form env)))

(symbol-macrolet ((thing 42))
  (show thing))
`````
`````common-lisp
;; Returns
((SHOW THING) 42)
`````


<a id="TITLE:ADP-GITHUB-WRITING:TAG8"></a>
## Lambda lists

The following table shows which elements are accepted by each kind of lambda list\:

<table>
<tr>
<th>Element</th><th>Ordinary</th><th>Destructuring</th><th>Macro</th></tr><tr>
<td>&#38;optional, &#38;rest, &#38;key, &#38;allow-other-keys, &#38;aux</td><td>Yes</td><td>Yes</td><td>Yes</td></tr><tr>
<td>&#38;whole</td><td>No</td><td>Yes</td><td>Yes</td></tr><tr>
<td>&#38;body</td><td>No</td><td>Yes</td><td>Yes</td></tr><tr>
<td>&#38;environment</td><td>No</td><td>No</td><td>Yes (top level only)</td></tr><tr>
<td>Nested patterns</td><td>No</td><td>Yes</td><td>Yes</td></tr><tr>
<td>Dotted tail (a . rest)</td><td>No</td><td>Yes</td><td>Yes</td></tr></table>

Nested patterns can be used for required parameters\, ```&optional``` and ```&key``` variables\, and ```&rest``` and ```&body``` variables\.


<a id="TITLE:ADP-GITHUB-WRITING:TAG9"></a>
## Errors

<a id="TITLE:ADP-GITHUB-WRITING:TAG10"></a>
### lambda\-list\-error

Signaled when the code is generated\, if the lambda list is malformed\. It is a subtype of ```simple-error``` and ```program-error```\. The lambda list can be retrieved with ```lambda-list-error-lambda-list```\.

`````common-lisp
(handler-case (ordinary-bind-form '(a &rest) 'arguments '())
  (lambda-list-error (e)
    (format t "~a" e)))
`````
`````text
;; Output
Invalid lambda list (A &REST):
  Missing variable after &REST.
`````
`````common-lisp
;; Returns
NIL
`````

<a id="TITLE:ADP-GITHUB-WRITING:TAG11"></a>
### binding\-error

Signaled when the generated code is executed\, if the values do not match the lambda list\. It is a subtype of ```simple-error``` and ```program-error```\. The lambda list and the values can be retrieved with ```binding-error-lambda-list``` and ```binding-error-arguments```\. The values of each list are checked before binding any of its variables\.

`````common-lisp
(handler-case (ordinary-bind (a b) (list 1)
                (list a b))
  (binding-error (e)
    (format t "~a" e)))
`````
`````text
;; Output
Too few arguments: expected at least 2.
  Lambda list: (A B)
  Arguments: (1)
`````
`````common-lisp
;; Returns
NIL
`````

`````common-lisp
(handler-case (eval (destructuring-bind-form '(&key a) '(list :b 1) '(a)))
  (binding-error (e)
    (format t "~a" e)))
`````
`````text
;; Output
Unknown keyword argument :B. Valid keywords: :A.
  Lambda list: (&KEY A)
  Arguments: (:B 1)
`````
`````common-lisp
;; Returns
NIL
`````


<a id="TITLE:ADP-GITHUB-WRITING:TAG12"></a>
## Reference

<a id="FUNCTION:PEAKY-BINDERS:ORDINARY-BIND"></a>
<a id="FUNCTION:ADP-GITHUB-WRITING:TAG13"></a>
#### Macro: pbinders\:ordinary\-bind \(lambda\-list arguments \&body body\)

`````text
Evaluate ARGUMENTS, which must produce a list, bind the variables of the
ordinary LAMBDA-LIST as if the list were the arguments of a function call and
evaluate BODY. Declarations at the beginning of BODY affect the variables of
LAMBDA-LIST.

A LAMBDA-LIST-ERROR is signaled at macroexpansion time if LAMBDA-LIST is
malformed. A BINDING-ERROR is signaled at run time if the list does not match
LAMBDA-LIST.
`````

<a id="FUNCTION:PEAKY-BINDERS:MACRO-BIND"></a>
<a id="FUNCTION:ADP-GITHUB-WRITING:TAG14"></a>
#### Macro: pbinders\:macro\-bind \(\(lambda\-list \&key name environment\) arguments \&body body\)

`````text
Evaluate ARGUMENTS, which must produce the list of arguments of a macro
call (without the operator), bind the variables of the macro LAMBDA-LIST and
evaluate BODY. Declarations at the beginning of BODY affect the variables of
LAMBDA-LIST.

NAME and ENVIRONMENT are evaluated and default to NIL. The &whole variable is
bound to (NAME . arguments) and the &environment variable is bound to the
value of ENVIRONMENT.

A LAMBDA-LIST-ERROR is signaled at macroexpansion time if LAMBDA-LIST is
malformed. A BINDING-ERROR is signaled at run time if the arguments do not
match LAMBDA-LIST.
`````

<a id="FUNCTION:PEAKY-BINDERS:ORDINARY-BIND-FORM"></a>
<a id="FUNCTION:ADP-GITHUB-WRITING:TAG15"></a>
#### Function: pbinders\:ordinary\-bind\-form \(lambda\-list arguments body\)

`````text
Return a form that evaluates the form ARGUMENTS, which must produce a list,
binds the variables of the ordinary LAMBDA-LIST as if the list were the
arguments of a function call and evaluates the forms in the list BODY.
Declarations at the beginning of BODY affect the variables of LAMBDA-LIST.

A LAMBDA-LIST-ERROR is signaled if LAMBDA-LIST is malformed. The returned form
signals a BINDING-ERROR if the list does not match LAMBDA-LIST.
`````

<a id="FUNCTION:PEAKY-BINDERS:DESTRUCTURING-BIND-FORM"></a>
<a id="FUNCTION:ADP-GITHUB-WRITING:TAG16"></a>
#### Function: pbinders\:destructuring\-bind\-form \(lambda\-list expression body\)

`````text
Return a form that evaluates the form EXPRESSION, destructures its value
with the destructuring LAMBDA-LIST and evaluates the forms in the list BODY.
Declarations at the beginning of BODY affect the variables of LAMBDA-LIST.

A LAMBDA-LIST-ERROR is signaled if LAMBDA-LIST is malformed. The returned form
signals a BINDING-ERROR if the value does not match LAMBDA-LIST.
`````

<a id="FUNCTION:PEAKY-BINDERS:MACRO-BIND-FORM"></a>
<a id="FUNCTION:ADP-GITHUB-WRITING:TAG17"></a>
#### Function: pbinders\:macro\-bind\-form \(lambda\-list arguments body \&key name environment\)

`````text
Return a form that evaluates the form ARGUMENTS, which must produce the
list of arguments of a macro call (without the operator), binds the variables
of the macro LAMBDA-LIST and evaluates the forms in the list BODY.
Declarations at the beginning of BODY affect the variables of LAMBDA-LIST.

NAME and ENVIRONMENT are forms inserted into the returned form. The &whole
variable is bound to (NAME . arguments) and the &environment variable is bound
to the value of ENVIRONMENT. Both default to NIL.

A LAMBDA-LIST-ERROR is signaled if LAMBDA-LIST is malformed. The returned form
signals a BINDING-ERROR if the arguments do not match LAMBDA-LIST.
`````

<a id="CLASS:PEAKY-BINDERS:LAMBDA-LIST-ERROR"></a>
<a id="CLASS:ADP-GITHUB-WRITING:TAG18"></a>
#### Condition: pbinders\:lambda\-list\-error
`````text
Signaled when the code is generated if a lambda list is malformed.
`````
* Direct slots\:
  * ```pbinders::lambda-list```
    * Allocation\: ```:instance```
    * Readers\: ```pbinders:lambda-list-error-lambda-list```


* Metaclass: ```sb-pcl::condition-class```
* Precedence list: ```pbinders:lambda-list-error```, ```simple-error```, ```simple-condition```, ```program-error```, ```error```, ```serious-condition```, ```condition```, ```sb-pcl::slot-object```, ```t```
* Direct superclasses: ```simple-error```, ```program-error```


<a id="CLASS:PEAKY-BINDERS:BINDING-ERROR"></a>
<a id="CLASS:ADP-GITHUB-WRITING:TAG19"></a>
#### Condition: pbinders\:binding\-error
`````text
Signaled when the generated code is executed if the values do not match the lambda list.
`````
* Direct slots\:
  * ```pbinders::lambda-list```
    * Allocation\: ```:instance```
    * Readers\: ```pbinders:binding-error-lambda-list```
  * ```pbinders::arguments```
    * Allocation\: ```:instance```
    * Readers\: ```pbinders:binding-error-arguments```


* Metaclass: ```sb-pcl::condition-class```
* Precedence list: ```pbinders:binding-error```, ```simple-error```, ```simple-condition```, ```program-error```, ```error```, ```serious-condition```, ```condition```, ```sb-pcl::slot-object```, ```t```
* Direct superclasses: ```simple-error```, ```program-error```


The symbol ```destructuring-bind``` is re\-exported from the ```common-lisp``` package\. See [destructuring\-bind](http://www.lispworks.com/reference/HyperSpec/Body/m_destru.htm)\.