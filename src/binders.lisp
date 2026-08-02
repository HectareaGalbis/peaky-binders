
(in-package #:pbinders)

;; -----------------------------------------------------------------------------
;; --------------------------- Required argument -------------------------------
;; -----------------------------------------------------------------------------

(defclass required-parser () ())

(defclass required-binder ()
  ((arg :initarg :arg :accessor required-binder-arg)))

(defparser req ()
  (make-instance 'required-parser))

(defmethod parse ((parser required-parser) expr)
  (unless (symbolp expr)
    (error 'parsing-error :message "Expected a symbol"
                          :relevance 0))
  (make-instance 'required-binder :arg expr))

(defmethod destructure ((binder required-binder) form)
  `((,(required-binder-arg binder)
     ,form)))


;; -----------------------------------------------------------------------------
;; --------------------------- Optional argument -------------------------------
;; -----------------------------------------------------------------------------

(defclass optional-parser () ())

(defclass optional-binder ()
  ((arg :initarg :arg :accessor optional-binder-arg)
   (init :initarg :init :accessor optional-binder-init)
   (argp :initarg :argp :accessor optional-binder-argp)))

(defparser opt ()
  (make-instance 'optional-parser))

(defmethod parse ((parser optional-parser) expr)
  (cond
    ((symbolp expr)
     (make-instance 'optional-binder :arg expr
                                     :init nil
                                     :argp nil))
    ((listp expr)
     (let ((len (length expr)))
       (unless (and (>= len 1) (<= len 3))
         (error 'parsing-error :message "Expected the form {var | (var [init-form [varp]])}"
                               :relevance 1))
       (destructuring-bind (arg &optional init (argp nil argpp)) expr
         (unless (symbolp arg)
           (error 'parsing-error :message "Expected a symbol as the first element of the list"
                                 :relevance 2))
         (unless (or (not argpp)
                     (and argp
                          (symbolp argp)))
           (error 'parsing-error :message "Expected a non-nil symbol as the third element of the list"
                                 :relevance 3))
         (make-instance 'optional-binder :arg arg
                                         :init init
                                         :argp argp))))
    (t (error 'parsing-error :message "Expected the form {var | (var [init-form [varp]])}"
                             :relevance 0))))

(defmethod destructure ((binder optional-binder) form)
  (with-slots (arg init argp) binder
    (with-gensyms (evaluated-form has-arg)
      `((,evaluated-form (multiple-value-list ,form))
        (,has-arg (and ,evaluated-form t))
        (,arg (if ,has-arg (car ,evaluated-form) ,init))
        ,@(when argp
            `((,argp ,has-arg)))))))


;; -----------------------------------------------------------------------------
;; ---------------------------------- or ---------------------------------------
;; -----------------------------------------------------------------------------

(defclass or-parser ()
  ((parsers :initarg :parsers :accessor or-parser-parsers)))

(defparser or (&rest parser-names)
  (when (null parser-names)
    (error 'parsing-definition-error :message "Expected at least one parser"))
  (make-instance 'or-parser :parsers (mapcar #'make-parser parser-names)))

(defmethod parse ((parser or-parser) expr)
  (with-slots (parsers) parser
    (let ((max-relevance nil)
          (max-error nil))
      (loop for parser in parsers
            for binder = (handler-case (parse parser expr)
                           (parsing-error (pe)
                             (let ((relevance (slot-value pe 'relevance)))
                               (when (or (not max-relevance)
                                         (< max-relevance relevance))
                                 (setf max-relevance relevance
                                       max-error pe)))
                             nil))
            if binder
              do (return-from parse binder))
      (error max-error))))


;; -----------------------------------------------------------------------------
;; ------------------------ Single argument checkers ---------------------------
;; -----------------------------------------------------------------------------

;; (defun check-required-arg (arg)
;;   "Check the syntax of a required argument"
;;   (check-type arg symbol))

;; (defun check-optional-arg (arg)
;;   "Check the syntax of an optional argument"
;;   (unless (or (symbolp arg)
;;               (listp arg))
;;     (error "Expected a symbol or a list: ~s" arg))
;;   (when (listp arg)
;;     (when (null arg)
;;       (error "Expected a non-null list: ~s" arg))
;;     (let ((arg-len (length arg)))
;;       (unless (<= arg-len 3)
;;         (error "Expected a list of less than 3 elements: ~s" arg)))
;;     (destructuring-bind (var &optional init varp) (ensure-list arg)
;;       (declare (ignore init))
;;       (check-type var symbol)
;;       (check-type varp symbol))))

;; (defun check-rest-arg (arg)
;;   "Check the syntax of a rest argument"
;;   (check-type arg symbol))

;; (defun check-key-arg (arg)
;;   "Check the syntax of a key argument"
;;   (unless (or (symbolp arg)
;;               (listp arg))
;;     (error "Expected a symbol or a list: ~s" arg))
;;   (when (listp arg)
;;     (when (null arg)
;;       (error "Expected a non-null list: ~s" arg))
;;     (let ((arg-len (length arg)))
;;       (unless (<= arg-len 3)
;;         (error "Expected a list of less than 3 elements: ~s" arg)))
;;     (destructuring-bind (var &optional init varp) (ensure-list arg)
;;       (declare (ignore init))
;;       (unless (or (symbolp var)
;;                   (listp var))
;;         (error "Expected a symbol or a list: ~s" var))
;;       (when (listp var)
;;         (unless (= (length var) 2)
;;           (error "Expected a list of 2 elements: ~s" var))
;;         (check-type (car var) symbol)
;;         (check-type (cadr var) symbol))
;;       (check-type varp symbol))))

;; (defun check-aux-arg (arg)
;;   "Check the syntax of an aux argument"
;;   (unless (or (symbolp arg)
;;               (listp arg))
;;     (error "Expected a symbol or a list: ~s" arg))
;;   (when (listp arg)
;;     (when (null arg)
;;       (error "Expected a non-null list: ~s" arg))
;;     (let ((arg-len (length arg)))
;;       (unless (<= arg-len 2)
;;         (error "Expected a list of 2 or less elements: ~s" arg)))
;;     (destructuring-bind (var &optional init) (ensure-list arg)
;;       (declare (ignore init))
;;       (unless (symbolp var)
;;         (error "Expected a symbol: ~s" var)))))

;; ;; -----------------------------------------------------------------------------
;; ;; -------------------------- List argument checkers ---------------------------
;; ;; -----------------------------------------------------------------------------

;; (defun check-required-args (required-args)
;;   "Check the syntax of a list of required arguments"
;;   (mapcar #'check-required-arg required-args))

;; (defun check-optional-args (optional-args)
;;   "Check the syntax of a list of optional arguments"
;;   (mapcar #'check-optional-arg optional-args))

;; (defun check-rest-args (rest-args)
;;   "Check the syntax of a list of rest arguments"
;;   (unless (= (length rest-args) 1)
;;     (error "Expected 1 rest argument: ~{~s~^ ~}" rest-args))
;;   (check-required-arg (car rest-args)))

;; (defun check-key-args (key-args)
;;   "Check the syntax of a list of key arguments"
;;   (loop for (key-arg . rest-key-args) on key-args
;;         do (if  (eq key-arg '&allow-other-keys)
;;                 (when rest-key-args
;;                   (error "&allow-other-keys must be at the end of key arguments: ~{~s~^ ~}" key-args))
;;                 (check-key-arg key-arg))))

;; (defun check-aux-args (aux-args)
;;   "Check the syntax of a list of aux arguments"
;;   (mapcar #'check-aux-arg aux-args))

;; ;; -----------------------------------------------------------------------------
;; ;; --------------------------- Keyword functions -------------------------------
;; ;; -----------------------------------------------------------------------------

;; (defun gather-keywords (lambda-list keywords)
;;   "Return the keywords used in the lambda list"
;;   (loop for arg in lambda-list
;;         if (member arg keywords)
;;           collect arg))

;; (defun reapeated-keywords-p (gathered-keywords)
;;   "Check for repeated keywords. Return the first found repeated keyword."
;;   (loop for (key . rest-keys) on gathered-keywords
;;         if (member key rest-keys)
;;           return (values t key)
;;         finally (return nil)))

;; (defun ordered-keywords-p (gathered-keywords keywords)
;;   "Check for unordered keywords. Return the first found misplaced keyword."
;;   (loop for (key1 key2 . rest-keys) on gathered-keywords
;;         while (and key1 key2)
;;         if (not (member key2 (member key1 keywords)))
;;           return (values nil key2)
;;         finally (return t)))

;; (defun check-keywords (lambda-list lambda-keywords)
;;   "Check whether the keywords from a lambda list are correct (not repeating and ordered)"
;;   (let ((keywords (gather-keywords lambda-list lambda-keywords)))
;;     (multiple-value-bind (repeatedp key) (reapeated-keywords-p keywords)
;;       (when repeatedp
;;         (error "Repeated keyword ~s" key)))
;;     (multiple-value-bind (orderedp key) (ordered-keywords-p keywords lambda-keywords)
;;       (unless orderedp
;;         (error "Misplaced keyword ~s" key)))))


;; (defun gather-until-keyword (lambda-list keywords)
;;   "Collect arguments until a keyword is found. Return the arguments and the rest of the lambda list."
;;   (loop for (arg . rest-args) on lambda-list
;;         if (member arg keywords)
;;           return (values vars (cons arg rest-args))
;;         else
;;           collect arg into vars
;;         finally (return (values vars nil))))

;; (defun gather-arguments (args keywords)
;;   "Return the first no-key arguments and a table with the key arguments"
;;   (let ((no-key-args nil)
;;         (keyword-args (make-hash-table :test 'eq)))
;;     (multiple-value-bind (first-args rest-args) (gather-until-keyword args keywords)
;;       (setf no-key-args first-args
;;             args rest-args))
;;     (loop while args
;;           for key = (car args)
;;           do (multiple-value-bind (key-args rest-args) (gather-until-keyword (cdr args) keywords)
;;                (print (list key key-args))
;;                (setf (gethash key keyword-args) key-args)
;;                (setf args rest-args)))
;;     (values no-key-args keyword-args)))

;; ;; -----------------------------------------------------------------------------
;; ;; ------------------------------- Parsers -------------------------------------
;; ;; -----------------------------------------------------------------------------

;; (defvar *ordinary-lambda-keywords* '(&optional &rest &key &aux))

;; (defun parse-ordinary-lambda (lambda-list)
;;   "Return values in the form: required optional rest key allow-other-keys-p aux"
;;   (check-keywords lambda-list *ordinary-lambda-keywords*)
;;   (multiple-value-bind (no-key-args keyword-args) (gather-arguments lambda-list *ordinary-lambda-keywords*)
;;     (let* ((required no-key-args)
;;            (optional (gethash '&optional keyword-args))
;;            (key (gethash '&key keyword-args))
;;            (allow-other-keys-p (member '&allow-other-keys key))
;;            (aux (gethash '&aux keyword-args)))
;;       (multiple-value-bind (rest restp) (gethash '&rest keyword-args)
;;         (check-required-args no-key-args)
;;         (check-optional-args optional)
;;         (when restp (check-rest-args rest))
;;         (check-key-args key)
;;         (check-aux-args aux)
;;         (values required optional (car rest) key allow-other-keys-p aux)))))

;; (defun parse-ordinary-lambda (lambda-list)
;;   "Return values in the form: required optional rest key allow-other-keys-p aux"
;;   (check-keywords lambda-list *ordinary-lambda-keywords*)
;;   (multiple-value-bind (no-key-args keyword-args) (gather-arguments lambda-list *ordinary-lambda-keywords*)
;;     (let* ((required no-key-args)
;;            (optional (gethash '&optional keyword-args))
;;            (key (gethash '&key keyword-args))
;;            (allow-other-keys-p (member '&allow-other-keys key))
;;            (aux (gethash '&aux keyword-args)))
;;       (multiple-value-bind (rest restp) (gethash '&rest keyword-args)
;;         (check-required-args no-key-args)
;;         (check-optional-args optional)
;;         (when restp (check-rest-args rest))
;;         (check-key-args key)
;;         (check-aux-args aux)
;;         (values required optional (car rest) key allow-other-keys-p aux)))))


;; ;; (defun collect-required-args (required-vars values)
;; ;;   (let ((required-vars-len (length required-vars))
;; ;;         (values-len (length values)))
;; ;;     (unless (<= required-vars-len values-len)
;; ;;       (error "Invalid number of arguments: ~a" required-vars-len)))
;; ;;   (loop for arg in required-vars
;; ;;         for (value . rest-values) on values
;; ;;         do (check-required-arg arg)
;; ;;         collect arg into req-args
;; ;;         collect value into req-vals
;; ;;         finally (return (values req-args req-vals rest-values))))

;; ;; (defun collect-optional-args (optional-args values)
;; ;;   (let (opt-vars opt-vals)
;; ;;     (loop for (arg . rest-args) on optional-args
;; ;;           for (value . rest-values) on values
;; ;;           do (check-optional-arg arg)
;; ;;              (destructuring-bind (var &optional init varp) (ensure-list arg)
;; ;;                (declare (ignore init))
;; ;;                (push var opt-vars)
;; ;;                (push value opt-vals)
;; ;;                (when varp
;; ;;                  (push varp opt-vars)
;; ;;                  (push t opt-vals)))
;; ;;           when (not rest-args)
;; ;;             return (values (nreverse opt-vars) (nreverse opt-vals) rest-values)
;; ;;           when (not rest-values)
;; ;;             do (loop for arg in rest-args
;; ;;                      do (check-optional-arg arg)
;; ;;                         (destructuring-bind (var &optional init varp) (ensure-list arg)
;; ;;                           (push var opt-vars)
;; ;;                           (push init opt-vals)
;; ;;                           (when varp
;; ;;                             (push varp opt-vars)
;; ;;                             (push nil opt-vals))))
;; ;;             and
;; ;;               return (values (nreverse opt-vars) (nreverse opt-vals) nil))))

;; ;; (defun collect-rest-args (rest-args values)
;; ;;   (unless (= (length rest-args) 1)
;; ;;     (error "Expected only one element: ~{~s~^ ~}" rest-args))
;; ;;   (check-rest-arg (car rest-args))
;; ;;   (values (car rest-args) values values))

;; ;; (defun collect-key-args (key-args values allow-other-keys-p)
;; ;;   (let ((key-args-map (make-hash-table :test 'eq))
;; ;;         key-vars key-vals)
;; ;;     (loop for key-arg in key-args
;; ;;           do
;; ;;              (check-key-arg key-arg)
;; ;;              (destructuring-bind ((key-name name) &optional init varp)
;; ;;                  (let ((name (car key-arg))
;; ;;                        (init-varp (cdr key-arg)))
;; ;;                    (list* (if (symbolp name)
;; ;;                               (list (make-keyword name) name)
;; ;;                               name)
;; ;;                           init-varp))
;; ;;                (setf (gethash key-name key-args-map) (list name init varp))))
;; ;;     (unless (evenp (length values))
;; ;;       (error "Expected an even number of elements: ~{~s~^ ~}" values))
;; ;;     (let ((other-keys-p (or allow-other-keys-p
;; ;;                             (let ((default '#:not-found))
;; ;;                               (not (eq (getf :allow-other-keys values default) default))))))
;; ;;       (loop for (key value . rest-values) on values by #'cddr
;; ;;             do
;; ;;                (multiple-value-bind (key-arg-info valuep) (gethash key key-args-map)
;; ;;                  (unless (or other-keys-p valuep)
;; ;;                    (error "Unknown key argument: ~s" key))
;; ;;                  (multiple-value-bind (name init varp) key-arg-info
;; ;;                    ))))))
