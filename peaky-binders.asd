
(defsystem "peaky-binders"
  :author "Héctor Galbis Sanchis"
  :description "Named binders for Common Lisp"
  :license "MIT"
  :depends-on ("alexandria" "vault")
  :components ((:module "src"
                :serial t
                :components ((:file "package")
                             (:file "peaky-binders")
                             (:file "binders")))))
