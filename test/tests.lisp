
(in-package #:peaky-binders/test)

(deftest destructuring-bind-is-reexported
  (is t (eq 'peaky-binders:destructuring-bind 'cl:destructuring-bind))
  (is '(:external :external)
      (list (nth-value 1 (find-symbol "DESTRUCTURING-BIND" '#:peaky-binders))
            (nth-value 1 (find-symbol "DESTRUCTURING-BIND" '#:cl)))))

(deftest ordinary-required
  (is '(1 2) (ordinary-bind (a b) '(1 2) (list a b)))
  (is :empty (ordinary-bind () '() :empty)))

(deftest ordinary-optional
  (is '(1 nil nil nil) (ordinary-bind (a &optional b (c nil cp)) '(1) (list a b c cp)))
  (is '(1 2 3 t) (ordinary-bind (a &optional b (c 0 cp)) '(1 2 3) (list a b c cp)))
  (is '(1 10) (ordinary-bind (a &optional (b (* a 10))) '(1) (list a b))))

(deftest ordinary-rest
  (is '(1 (2 3)) (ordinary-bind (a &rest r) '(1 2 3) (list a r)))
  (is '(1 nil) (ordinary-bind (a &rest r) '(1) (list a r))))

(deftest ordinary-key
  (is '(1 2 nil nil) (ordinary-bind (&key a (b 2) (c nil cp)) '(:a 1) (list a b c cp)))
  (is '(5 t) (ordinary-bind (&key ((:the-key x) 0 xp)) '(:the-key 5) (list x xp)))
  (is '(3 4) (ordinary-bind (&key ((the-key x)) y) '(the-key 3 :y 4) (list x y)))
  (is 1 (ordinary-bind (&key a) '(:a 1 :a 2) a))
  (is '(1 (:k 3) 3) (ordinary-bind (a &rest r &key k) '(1 :k 3) (list a r k))))

(deftest ordinary-allow-other-keys
  (is 1 (ordinary-bind (&key a &allow-other-keys) '(:b 2 :a 1) a))
  (is 1 (ordinary-bind (&key a) '(:b 2 :a 1 :allow-other-keys t) a))
  (signals binding-error (ordinary-bind (&key a) '(:b 2 :a 1 :allow-other-keys nil) a)))

(deftest ordinary-aux
  (is '(1 2 3) (ordinary-bind (a &aux (b (1+ a)) (c (1+ b))) '(1) (list a b c)))
  (is '(1 nil) (ordinary-bind (a &aux b) '(1) (list a b))))

(deftest ordinary-evaluates-arguments-once
  (let ((count 0))
    (is '(1 2 1) (ordinary-bind (a b) (progn (incf count) (list 1 2)) (list a b count)))))

(deftest ordinary-declarations
  (is 3 (ordinary-bind (a b) '(1 2) (declare (fixnum a b)) (+ a b)))
  (is 1 (ordinary-bind (special-x) '(1)
          (declare (special special-x))
          (symbol-value 'special-x))))

(deftest ordinary-runtime-errors
  (signals binding-error (ordinary-bind (a b) '(1) (list a b)))
  (signals binding-error (ordinary-bind (a) '(1 2) a))
  (signals binding-error (ordinary-bind (a &optional b) '(1 2 3) (list a b)))
  (signals binding-error (ordinary-bind (&key a) '(:a) a))
  (signals binding-error (ordinary-bind (&key a) '(:a 1 :b) a))
  (signals binding-error (ordinary-bind (&key a) '(:b 1) a)))

(deftest ordinary-binding-error-slots
  (handler-case (progn (ordinary-bind (a b) '(1) (list a b))
                       (report-failure "no error"))
    (binding-error (e)
      (is '(a b) (binding-error-lambda-list e))
      (is '(1) (binding-error-arguments e)))))

(deftest ordinary-syntax-errors
  (signals lambda-list-error (expand '(ordinary-bind ((a b)) x)))
  (signals lambda-list-error (expand '(ordinary-bind (&whole w a) x)))
  (signals lambda-list-error (expand '(ordinary-bind (&body b) x)))
  (signals lambda-list-error (expand '(ordinary-bind (a &environment e) x)))
  (signals lambda-list-error (expand '(ordinary-bind (a . b) x)))
  (signals lambda-list-error (expand '(ordinary-bind (a &rest) x)))
  (signals lambda-list-error (expand '(ordinary-bind (a &rest b c) x)))
  (signals lambda-list-error (expand '(ordinary-bind (&key a &optional b) x)))
  (signals lambda-list-error (expand '(ordinary-bind (&optional a &optional b) x)))
  (signals lambda-list-error (expand '(ordinary-bind (&allow-other-keys) x)))
  (signals lambda-list-error (expand '(ordinary-bind (&optional (a 1 2 3)) x)))
  (signals lambda-list-error (expand '(ordinary-bind (t) x)))
  (signals lambda-list-error (expand '(ordinary-bind (:a) x)))
  (signals lambda-list-error (expand '(ordinary-bind (&aux (a 1 2)) x))))

(defmacro with-macro-bind ((name lambda-list) &body body)
  (let ((form (gensym "FORM"))
        (env (gensym "ENV"))
        (ignored (gensym "IGNORED")))
    `(defmacro ,name (&whole ,form &environment ,env &rest ,ignored)
       (declare (ignore ,ignored) (ignorable ,env))
       (macro-bind (,lambda-list :name ',name :environment ,env) (cdr ,form)
         ,@body))))

(with-macro-bind (mb-whole (&whole w a b))
  `'(,w ,a ,b))

(with-macro-bind (mb-nested ((a b) &optional ((c d) '(3 4) cdp) &body body))
  `'(,a ,b ,c ,d ,cdp ,body))

(with-macro-bind (mb-env (&environment env form))
  `',(macroexpand form env))

(with-macro-bind (mb-dotted (a . rest))
  `'(,a ,rest))

(with-macro-bind (mb-key (&key ((:k (x y))) (z 0 zp)))
  `'(,x ,y ,z ,zp))

(deftest macro-whole-uses-name
  (is '((mb-whole 1 2) 1 2) (mb-whole 1 2))
  (is '((the-name a b) a b)
      (macro-bind ((&whole w x y) :name 'the-name) '(a b) (list w x y)))
  (is '((nil a) a)
      (macro-bind ((&whole w x)) '(a) (list w x))))

(deftest macro-nested-patterns
  (is '(1 2 3 4 nil ()) (mb-nested (1 2)))
  (is '(1 2 5 6 t (x y)) (mb-nested (1 2) (5 6) x y))
  (is '(1 2 5 6 t ()) (mb-nested (1 2) (5 6)))
  (is '(8 9 0 nil) (mb-key :k (8 9))))

(deftest macro-environment
  (is 42 (symbol-macrolet ((thing 42))
           (mb-env thing)))
  (is 'thing (mb-env thing))
  (is :env (macro-bind ((&environment e a) :environment :env) '(1)
             (declare (ignore a))
             e))
  (is nil (macro-bind ((&environment e)) '() e)))

(deftest macro-environment-after-required
  (is '(1 :env 2)
      (macro-bind ((a &environment e b) :environment :env) '(1 2) (list a e b))))

(deftest macro-dotted
  (is '(1 (2 3)) (mb-dotted 1 2 3))
  (is '(1 nil) (mb-dotted 1)))

(deftest macro-runtime-errors
  (signals binding-error (macro-bind (((a b))) '((1)) (list a b)))
  (signals binding-error (macro-bind ((a)) '(1 2) a))
  (signals binding-error (macro-bind ((&key a)) '(:b 1) a))
  (signals binding-error (macro-bind ((a)) '(1 . 2) a)))

(deftest macro-syntax-errors
  (signals lambda-list-error (expand '(macro-bind ((a &whole w)) x)))
  (signals lambda-list-error (expand '(macro-bind ((&environment e &environment f)) x)))
  (signals lambda-list-error (expand '(macro-bind (((a &environment e))) x)))
  (signals lambda-list-error (expand '(macro-bind ((&rest a &body b)) x)))
  (signals lambda-list-error (expand '(macro-bind ((&whole)) x))))

(defmacro dbind (lambda-list expression &body body)
  (destructuring-bind-form lambda-list expression body))

(deftest destructuring-bind-form-patterns
  (is '(1 2 3 4 nil nil) (dbind (a (b c) &optional (d 4 dp) . e) '(1 (2 3)) (list a b c d dp e)))
  (is '((1 2 3) 1 2 3) (dbind (&whole w a &rest (b c)) '(1 2 3) (list w a b c)))
  (is '((2 3) 2 3) (dbind (a (&whole w b c)) '(1 (2 3)) (declare (ignore a)) (list w b c)))
  (is '(1 2) (dbind (a . b) '(1 . 2) (list a b)))
  (is '(1 (2)) (dbind (a &body b) '(1 2) (list a b))))

(deftest destructuring-bind-form-errors
  (signals binding-error (dbind ((a b)) '((1)) (list a b)))
  (signals binding-error (dbind ((a b)) '(1) (list a b)))
  (signals binding-error (dbind (a) '(1 . 2) a))
  (signals lambda-list-error (expand '(dbind (a &environment e) x))))

(deftest duplicate-variables
  (signals lambda-list-error (expand '(ordinary-bind (a a) x)))
  (signals lambda-list-error (expand '(ordinary-bind (a &optional a) x)))
  (signals lambda-list-error (expand '(ordinary-bind (a &optional (b 1 a)) x)))
  (signals lambda-list-error (expand '(ordinary-bind (&optional (a 1 ap) &key (b 2 ap)) x)))
  (signals lambda-list-error (expand '(ordinary-bind (a &rest a) x)))
  (signals lambda-list-error (expand '(ordinary-bind (a &key a) x)))
  (signals lambda-list-error (expand '(ordinary-bind (a &key ((:k a))) x)))
  (signals lambda-list-error (expand '(ordinary-bind (a &aux a) x)))
  (signals lambda-list-error (expand '(ordinary-bind (&aux a a) x)))
  (signals lambda-list-error (expand '(dbind (&whole w w) x)))
  (signals lambda-list-error (expand '(dbind (a . a) x)))
  (signals lambda-list-error (expand '(dbind (a (b a)) x)))
  (signals lambda-list-error (expand '(dbind ((a b) &key ((:k (b c)))) x)))
  (signals lambda-list-error (expand '(dbind (a (&whole a b)) x)))
  (signals lambda-list-error (expand '(dbind ((a) &rest (b a)) x)))
  (signals lambda-list-error (expand '(macro-bind ((&whole w &environment w)) x)))
  (signals lambda-list-error (expand '(macro-bind ((a &environment a)) x)))
  (signals lambda-list-error (expand '(macro-bind (((a b) &body (c b))) x))))

(deftest duplicate-variables-error-lambda-list
  (handler-case (progn (expand '(dbind (a (b a)) x))
                       (report-failure "no error"))
    (lambda-list-error (e)
      (is '(a (b a)) (lambda-list-error-lambda-list e)))))

(deftest distinct-variables-accepted
  (is '(1 2 t 3 nil 4)
      (ordinary-bind (a &optional (b 0 bp) &key (c 0 cp) &aux (d 4)) '(1 2 :c 3)
        (list a b bp c (not cp) d)))
  (is '(1 2 3) (dbind (a (b c)) '(1 (2 3)) (list a b c))))

(deftest duplicate-keywords
  (signals lambda-list-error (expand '(ordinary-bind (&key a ((:a b))) x)))
  (signals lambda-list-error (expand '(ordinary-bind (&key ((:k a)) ((:k b))) x)))
  (signals lambda-list-error (expand '(ordinary-bind (&key ((k a)) ((k b))) x)))
  (signals lambda-list-error (expand '(dbind ((&key a ((:a b)))) x)))
  (signals lambda-list-error (expand '(macro-bind ((&key a ((:a b)))) x))))

(deftest duplicate-keywords-in-different-levels-accepted
  (is '(1 2) (dbind ((&key a) &key ((:a b))) '((:a 1) :a 2) (list a b)))
  (is '(1 2) (ordinary-bind (&key ((:a x)) ((a y))) '(:a 1 a 2) (list x y))))
