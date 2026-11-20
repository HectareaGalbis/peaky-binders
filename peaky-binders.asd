
(defsystem "peaky-binders"
  :author "Héctor Galbis Sanchis"
  :description "Functions that generate the code to bind lambda lists"
  :license "MIT"
  :components ((:module "src"
                :serial t
                :components ((:file "package")
                             (:file "conditions")
                             (:file "runtime")
                             (:file "parse")
                             (:file "generate")
                             (:file "macros"))))
  :in-order-to ((test-op (test-op "peaky-binders/test"))))

(defsystem "peaky-binders/test"
  :depends-on ("peaky-binders")
  :components ((:module "test"
                :serial t
                :components ((:file "package")
                             (:file "harness")
                             (:file "tests"))))
  :perform (test-op (op c)
             (unless (uiop:symbol-call '#:peaky-binders/test '#:run-tests)
               (error "peaky-binders tests failed"))))
