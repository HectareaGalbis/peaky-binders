
(in-package #:pbinders)


(defvault peaky-binders)


(define-condition source-error (program-error)
  ((sources :accessor source-error-sources :initform nil)
   (message :initarg :message :accessor source-error-message
            :initform (error "Argument :message required"))
   (relevance :initarg :relevance :accessor source-error-relevance
              :initform 0))
  (:report (lambda (pe strm)
             (let ((*print-circle* nil))
               (loop for source in (source-error-sources pe)
                     do (format strm "From: ~s~%" source))
               (format strm "~a" (source-error-message pe))))))

(defun push-source (c source)
  (if (not (eq source (car (source-error-sources c))))
      (push source (source-error-sources c))))

;; ------ Parsing ------

(define-condition parsing-definition-error (source-error) ())
(define-condition parsing-error (source-error) ())

(defun parsing-error (datum &rest args)
  (error 'parsing-error :message (apply #'format nil datum args)))

(define-compiler-macro parsing-error (datum &rest args)
  `(error 'parsing-error :message (format nil ,datum ,@args)))

(defmacro defparser (name (&rest args) &body body)
  (check-type name symbol)
  `(define-vault-function peaky-binders ,name (,@args)
     ,@body))

(defun canonize-parser-name (parser-name)
  (ensure-list parser-name))

(defun parser-name-p (parser-name)
  (vault-function-p 'peaky-binders (car (canonize-parser-name parser-name))))

(defun make-parser% (parser-name)
  (vault-apply 'peaky-binders (car parser-name) (cdr parser-name)))

(defun make-parser (parser-name)
  (handler-bind ((parsing-definition-error (lambda (c) (push-source c parser-name))))
    (unless (parser-name-p parser-name)
      (error 'parsing-definition-error :message "Unknown parser"))
    (make-parser% (canonize-parser-name parser-name))))

(defgeneric parse (parser expr))

(defmethod parse :around (parser expr)
  (handler-bind ((parsing-error (lambda (c) (push-source c expr))))
    (call-next-method)))

;; ------ Destructuring ------

(define-condition destructuring-error (source-error) ())

(defun destructuring-error (datum &rest args)
  (error 'destructuring-error :message (apply #'format nil datum args)))

(define-compiler-macro destructuring-error (datum &rest args)
  `(error 'destructuring-error :message (format nil ,datum ,@args)))

(defgeneric destructure (binder form))

(defmethod destructure :around (binder form)
  (handler-bind ((destructuring-error (lambda (c) (push-source c form))))
    (call-next-method)))


;; ------ Binding ------

(defun make-bindings (parser expr form)
  (destructure (parse (make-parser parser) expr) form))

(defmacro bind (parser expr form &body body)
  `(let* ,(make-bindings parser expr form)
     ,@body))
