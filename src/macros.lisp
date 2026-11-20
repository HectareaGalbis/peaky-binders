
(in-package #:peaky-binders)

(defmacro ordinary-bind (lambda-list arguments &body body)
  (ordinary-bind-form lambda-list arguments body))

(defmacro macro-bind ((lambda-list &key name environment) arguments &body body)
  (macro-bind-form lambda-list arguments body :name name :environment environment))
