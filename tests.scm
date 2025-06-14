(load "faster-minikanren/mk-vicare.scm")
(load "faster-minikanren/mk.scm")
(load "aqua.scm")
(load "faster-minikanren/test-check.scm")


(test "append"
  (run 1 (q)
       (evalo '(letrec ((append (lambda (s l)
                                  (if (null? s)
                                      l
                                      (cons (car s) (append (cdr s) l))))))
                 (append '(a b c) '(d e)))
              q))
  '((a b c d e)))

(test "append-backwards"
  (run* (s l)
        (evalo `(letrec ((append (lambda (s l)
                                   (if (null? s)
                                       l
                                       (cons (car s) (append (cdr s) l))))))
                  (append ',s ',l))
               '(a b c d e)))
  '((() (a b c d e))
    ((a) (b c d e))
    ((a b) (c d e))
    ((a b c) (d e))
    ((a b c d) (e))
    ((a b c d e) ())))

(test "refl-1"
      (run 1 (q)
           (evalo '(meaning 1 'error) q))
      '(1))

(test "refl-2"
      (run 1 (q)
           (evalo '(mu (e r) 1) q))
      '((mu-reifier (e r) 1)))

(test "refl-3"
      (run 1 (q)
           (evalo '((mu (e r) 1)) q))
      '(1))

(test "refl-4"
      (run 1 (q)
           (evalo '((mu (e r) (meaning 1 r))) q))
      '(1))

(test "refl-5"
      (run 1 (q)
           (evalo '((mu (e r) (meaning (car e) r)) 1) q))
      '(1))

(test "refl-6"
      (run 1 (q)
           (evalo '((mu (e r) (meaning (car e) r)) ((lambda (x) x) 1)) q))
      '(1))

(test "refl-7"
      (run 1 (q)
           (evalo '((mu (e1 r1) ((mu (e2 r2) (meaning 1 r2))))) q))
      '(1))

(test "refl-8"
      (run 1 (q)
           (evalo '((mu (e1 r1) ((mu (e2 r2) ((mu (e3 r3) (meaning 'level r3))))))) q))
      '((s z)))

(test "refl-8-backwards-1"
      (run 2 (q)
           (evalo `((mu (e1 r1) ((mu (e2 r2) ((mu (e3 r3) (meaning ',q r3))))))) '(s z)))
      '((quote (s z)) level))

(test "refl-8-backwards-2"
      (run 2 (q)
           (evalo `((mu (e1 r1) ((mu (e2 r2) ((mu (e3 r3) (meaning 'level ,q))))))) '(s z)))
      '(r3
        ('((level val s z) . _.0)
         (absento (closure _.0) (mu-reifier _.0) (prim _.0)))))

#!eof
