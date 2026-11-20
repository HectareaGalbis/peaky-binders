
(in-package #:peaky-binders)

(define-condition lambda-list-error (simple-error program-error)
  ((lambda-list :initarg :lambda-list :reader lambda-list-error-lambda-list
                :documentation "The malformed lambda list."))
  (:documentation "Signaled when the code is generated if a lambda list is malformed.")
  (:report (lambda (condition stream)
             (format stream "Invalid lambda list ~s:~%  ~?"
                     (lambda-list-error-lambda-list condition)
                     (simple-condition-format-control condition)
                     (simple-condition-format-arguments condition)))))

(defun lambda-list-error (lambda-list control &rest arguments)
  (error 'lambda-list-error :lambda-list lambda-list
                            :format-control control
                            :format-arguments arguments))

(define-condition binding-error (simple-error program-error)
  ((lambda-list :initarg :lambda-list :reader binding-error-lambda-list
                :documentation "The lambda list, or nested pattern, that the values do not match.")
   (arguments :initarg :arguments :reader binding-error-arguments
              :documentation "The list of values that does not match the lambda list."))
  (:documentation "Signaled when the generated code is executed if the values do not match the lambda list.")
  (:report (lambda (condition stream)
             (format stream "~?~%  Lambda list: ~s~%  Arguments: ~s"
                     (simple-condition-format-control condition)
                     (simple-condition-format-arguments condition)
                     (binding-error-lambda-list condition)
                     (binding-error-arguments condition)))))

(defun binding-error (lambda-list arguments control &rest format-arguments)
  (error 'binding-error :lambda-list lambda-list
                        :arguments arguments
                        :format-control control
                        :format-arguments format-arguments))
