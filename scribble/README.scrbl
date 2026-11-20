(in-package #:peaky-binders-docs)

@output-file["/README.md"]

@title[:toc nil]{Peaky Binders}

Welcome to Peaky Binders!

This library defines functions that return the code needed to bind the variables of a lambda list. They are meant to write macros like @code{destructuring-bind}, but they support three kinds of lambda lists:

@itemize[
  @item{Ordinary lambda lists.}
  @item{Destructuring lambda lists.}
  @item{Macro lambda lists, where you can choose the macro name used by @code{&whole}.}
]

Every symbol is exported from the @code{peaky-binders} package, although you can use the nickname @code{pbinders}.

@table-of-contents[]


@subtitle{Installation}

Clone the repository into a directory where ASDF can find it:

@code-block[:lang "sh"]{
cd ~/common-lisp
git clone https://github.com/HectareaGalbis/peaky-binders.git
}

And load it:

@code-block[:lang "common-lisp"]{
(asdf:load-system "peaky-binders")
}


@subtitle{Binding macros}

The library defines two macros, @code{ordinary-bind} and @code{macro-bind}, and re-exports @code{cl:destructuring-bind}, so the three kinds of lambda lists can be used from the same package.

@subsubtitle{ordinary-bind}

@code-block[:lang "common-lisp"]{
(ordinary-bind lambda-list arguments &body body)
}

Evaluates @code{arguments}, which must produce a list, and binds the variables of the ordinary @code{lambda-list} as if the list were the arguments of a function call. Then, @code{body} is evaluated.

@example{
(ordinary-bind (a &optional (b (* a 10)) &rest r &key c) (list 1 2 :c 3)
  (list a b r c))
}

@example{
(ordinary-bind (a &optional (b (* a 10) bp)) (list 1)
  (list a b bp))
}

Declarations at the beginning of @code{body} affect the variables of the lambda list:

@example{
(ordinary-bind (a b) (list 1 2)
  (declare (fixnum a b))
  (+ a b))
}

@subsubtitle{destructuring-bind}

It is the same symbol as @code{cl:destructuring-bind}.

@example{
(eq 'peaky-binders:destructuring-bind 'cl:destructuring-bind)
}

@subsubtitle{macro-bind}

@code-block[:lang "common-lisp"]{
(macro-bind (lambda-list &key name environment) arguments &body body)
}

Evaluates @code{arguments}, which must produce the list of arguments of a macro call (without the operator), binds the variables of the macro @code{lambda-list} and evaluates @code{body}.

@itemize[
  @item{The @code{&whole} variable is bound to a list whose @code{car} is the value of @code{name} and whose @code{cdr} is the list of arguments.}
  @item{The @code{&environment} variable is bound to the value of @code{environment}.}
]

Both @code{name} and @code{environment} are evaluated. They default to @code{nil}.

@example{
(macro-bind ((&whole w (a b) &body body) :name 'my-macro) '((1 2) x y)
  (list w a b body))
}

@example{
(macro-bind ((&environment env a) :environment :some-environment) '(1)
  (list env a))
}


@subtitle{Writing your own macros}

The macros above are built with the following functions. They receive a lambda list, a form and a list of body forms, and return a form that evaluates the given form, binds the variables of the lambda list and evaluates the body forms.

@code-block[:lang "common-lisp"]{
(ordinary-bind-form lambda-list arguments body)
(destructuring-bind-form lambda-list expression body)
(macro-bind-form lambda-list arguments body &key name environment)
}

In @code{macro-bind-form}, @code{name} and @code{environment} are forms that are inserted into the generated code.

@example{
(destructuring-bind-form '(a (b c)) 'expression '((list a b c)))
}

For example, this is a version of @code{defmacro} that uses @code{macro-bind-form}:

@example|{
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
}|


@subtitle{Lambda lists}

The following table shows which elements are accepted by each kind of lambda list:

@table[
  @row[:header t
    @cell{Element} @cell{Ordinary} @cell{Destructuring} @cell{Macro}
  ]
  @row[
    @cell{&optional, &rest, &key, &allow-other-keys, &aux} @cell{Yes} @cell{Yes} @cell{Yes}
  ]
  @row[
    @cell{&whole} @cell{No} @cell{Yes} @cell{Yes}
  ]
  @row[
    @cell{&body} @cell{No} @cell{Yes} @cell{Yes}
  ]
  @row[
    @cell{&environment} @cell{No} @cell{No} @cell{Yes (top level only)}
  ]
  @row[
    @cell{Nested patterns} @cell{No} @cell{Yes} @cell{Yes}
  ]
  @row[
    @cell{Dotted tail (a . rest)} @cell{No} @cell{Yes} @cell{Yes}
  ]
]

Nested patterns can be used for required parameters, @code{&optional} and @code{&key} variables, and @code{&rest} and @code{&body} variables.


@subtitle{Errors}

@subsubtitle{lambda-list-error}

Signaled when the code is generated, if the lambda list is malformed. It is a subtype of @code{simple-error} and @code{program-error}. The lambda list can be retrieved with @code{lambda-list-error-lambda-list}.

@example{
(handler-case (ordinary-bind-form '(a &rest) 'arguments '())
  (lambda-list-error (e)
    (format t "~a" e)))
}

@subsubtitle{binding-error}

Signaled when the generated code is executed, if the values do not match the lambda list. It is a subtype of @code{simple-error} and @code{program-error}. The lambda list and the values can be retrieved with @code{binding-error-lambda-list} and @code{binding-error-arguments}. The values of each list are checked before binding any of its variables.

@example{
(handler-case (ordinary-bind (a b) (list 1)
                (list a b))
  (binding-error (e)
    (format t "~a" e)))
}

@example{
(handler-case (eval (destructuring-bind-form '(&key a) '(list :b 1) '(a)))
  (binding-error (e)
    (format t "~a" e)))
}


@subtitle{Reference}

@function-description[ordinary-bind]

@function-description[macro-bind]

@function-description[ordinary-bind-form]

@function-description[destructuring-bind-form]

@function-description[macro-bind-form]

@condition-description[lambda-list-error]

@condition-description[binding-error]

The symbol @code{destructuring-bind} is re-exported from the @code{common-lisp} package. See @clref[destructuring-bind].
