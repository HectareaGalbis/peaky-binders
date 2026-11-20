
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
  (make-bind-form (parse-lambda-list lambda-list :ordinary) arguments body))

(defun destructuring-bind-form (lambda-list expression body)
  (make-bind-form (parse-lambda-list lambda-list :destructuring) expression body))

(defun macro-bind-form (lambda-list arguments body &key name environment)
  (make-bind-form (parse-lambda-list lambda-list :macro) arguments body
                  :whole (lambda (list) `(cons ,name ,list))
                  :environment environment))
