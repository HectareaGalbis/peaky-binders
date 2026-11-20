
(in-package #:peaky-binders)

(defstruct (pll (:constructor make-pll (source)))
  source
  whole
  environment
  environmentp
  required
  optional
  rest
  keyp
  keys
  allow-other-keys
  aux)

(defun proper-list-p (x)
  (loop (cond ((null x) (return t))
              ((atom x) (return nil))
              (t (setf x (cdr x))))))

(defun variablep (x)
  (and (symbolp x)
       (not (constantp x))
       (not (member x lambda-list-keywords))))

(defun check-variable (x lambda-list)
  (unless (variablep x)
    (lambda-list-error lambda-list "~s is not a valid variable name." x))
  x)

(defun parse-pattern (x kind lambda-list)
  (if (and (consp x) (not (eq kind :ordinary)))
      (parse-lambda-list x :destructuring)
      (check-variable x lambda-list)))

(defun parse-optional (spec kind lambda-list)
  (cond
    ((consp spec)
     (unless (and (proper-list-p spec) (<= 1 (length spec) 3))
       (lambda-list-error lambda-list
                          "~s is not a valid &optional parameter specifier." spec))
     (destructuring-bind (var &optional init svar) spec
       (list (parse-pattern var kind lambda-list)
             init
             (and svar (check-variable svar lambda-list)))))
    (t
     (list (check-variable spec lambda-list) nil nil))))

(defun keyword-of (symbol)
  (intern (symbol-name symbol) :keyword))

(defun parse-key (spec kind lambda-list)
  (cond
    ((consp spec)
     (unless (and (proper-list-p spec) (<= 1 (length spec) 3))
       (lambda-list-error lambda-list
                          "~s is not a valid &key parameter specifier." spec))
     (destructuring-bind (name &optional init svar) spec
       (multiple-value-bind (keyword pattern)
           (cond
             ((consp name)
              (unless (and (proper-list-p name)
                           (= (length name) 2)
                           (symbolp (first name)))
                (lambda-list-error lambda-list
                                   "~s is not a valid (keyword-name var) form." name))
              (values (first name) (parse-pattern (second name) kind lambda-list)))
             (t
              (values (keyword-of (check-variable name lambda-list)) name)))
         (list keyword pattern init (and svar (check-variable svar lambda-list))))))
    (t
     (list (keyword-of (check-variable spec lambda-list)) spec nil nil))))

(defun parse-aux (spec lambda-list)
  (cond
    ((consp spec)
     (unless (and (proper-list-p spec) (<= 1 (length spec) 2))
       (lambda-list-error lambda-list
                          "~s is not a valid &aux parameter specifier." spec))
     (list (check-variable (first spec) lambda-list) (second spec)))
    (t
     (list (check-variable spec lambda-list) nil))))

(defun allowed-keywords (kind)
  (ecase kind
    (:ordinary '(&optional &rest &key &allow-other-keys &aux))
    (:destructuring '(&whole &optional &rest &body &key &allow-other-keys &aux))
    (:macro '(&whole &environment &optional &rest &body &key &allow-other-keys &aux))))

(defparameter *section-ranks*
  '((&optional . 1) (&rest . 2) (&body . 2) (&key . 3) (&allow-other-keys . 4) (&aux . 5)))

(defun parse-lambda-list (lambda-list kind)
  (unless (listp lambda-list)
    (lambda-list-error lambda-list "A lambda list must be a list."))
  (let ((pll (make-pll lambda-list))
        (allowed (allowed-keywords kind))
        (state :required)
        (resume nil)
        (previous nil)
        (rank 0))
    (flet ((fail (control &rest arguments)
             (apply #'lambda-list-error lambda-list control arguments)))
      (do ((tail lambda-list (cdr tail)))
          ((atom tail)
           (when (member state '(:whole :environment :rest))
             (fail "Missing variable after ~s." previous))
           (when tail
             (unless (and (not (eq kind :ordinary))
                          (member state '(:required :optional)))
               (fail "Unexpected dotted tail ~s." tail))
             (setf (pll-rest pll) (check-variable tail lambda-list))))
        (let ((item (car tail)))
          (cond
            ((member item lambda-list-keywords)
             (unless (member item allowed)
               (fail "~s is not allowed here." item))
             (when (member state '(:whole :environment :rest))
               (fail "Missing variable after ~s." previous))
             (setf previous item)
             (case item
               (&whole
                (unless (eq tail lambda-list)
                  (fail "&whole must appear first."))
                (setf state :whole))
               (&environment
                (when (pll-environmentp pll)
                  (fail "&environment appears more than once."))
                (setf (pll-environmentp pll) t
                      resume state
                      state :environment))
               (t
                (let ((item-rank (cdr (assoc item *section-ranks*))))
                  (when (<= item-rank rank)
                    (fail "~s is misplaced or duplicated." item))
                  (setf rank item-rank)
                  (setf state
                        (ecase item
                          (&optional :optional)
                          ((&rest &body) :rest)
                          (&key
                           (setf (pll-keyp pll) t)
                           :key)
                          (&allow-other-keys
                           (unless (pll-keyp pll)
                             (fail "&allow-other-keys must follow &key."))
                           (setf (pll-allow-other-keys pll) t)
                           :none)
                          (&aux :aux)))))))
            (t
             (ecase state
               (:whole
                (setf (pll-whole pll) (check-variable item lambda-list)
                      state :required))
               (:environment
                (setf (pll-environment pll) (check-variable item lambda-list)
                      state resume))
               (:required
                (push (parse-pattern item kind lambda-list) (pll-required pll)))
               (:optional
                (push (parse-optional item kind lambda-list) (pll-optional pll)))
               (:rest
                (setf (pll-rest pll) (parse-pattern item kind lambda-list)
                      state :none))
               (:key
                (push (parse-key item kind lambda-list) (pll-keys pll)))
               (:aux
                (push (parse-aux item lambda-list) (pll-aux pll)))
               (:none
                (fail "Unexpected ~s after ~s." item previous))))))))
    (setf (pll-required pll) (nreverse (pll-required pll))
          (pll-optional pll) (nreverse (pll-optional pll))
          (pll-keys pll) (nreverse (pll-keys pll))
          (pll-aux pll) (nreverse (pll-aux pll)))
    pll))
