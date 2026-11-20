
(in-package #:peaky-binders)

(defun check-arguments (arguments lambda-list nrequired noptional restp keyp keys
                        allow-other-keys-p)
  (flet ((fail (control &rest format-arguments)
           (apply #'binding-error lambda-list arguments control format-arguments)))
    (let ((tail arguments))
      (dotimes (i nrequired)
        (unless (consp tail)
          (fail "Too few arguments: expected at least ~d." nrequired))
        (setf tail (cdr tail)))
      (dotimes (i noptional)
        (if (consp tail)
            (setf tail (cdr tail))
            (return)))
      (cond
        (keyp
         (let ((unknown '()))
           (do ((rest tail (cddr rest)))
               ((null rest))
             (unless (and (consp rest) (consp (cdr rest)))
               (fail "Malformed keyword arguments ~s: expected a property list." tail))
             (let ((key (car rest)))
               (unless (or (eq key :allow-other-keys)
                           (member key keys))
                 (pushnew key unknown))))
           (when (and unknown
                      (not allow-other-keys-p)
                      (not (getf tail :allow-other-keys)))
             (fail "Unknown keyword argument~p ~{~s~^, ~}. Valid keywords: ~{~s~^, ~}."
                   (length unknown) (reverse unknown) keys))))
        (restp)
        ((null tail))
        ((consp tail)
         (fail "Too many arguments: expected at most ~d." (+ nrequired noptional)))
        (t
         (fail "Unexpected dotted tail ~s." tail))))
    arguments))
