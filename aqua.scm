;; The definition of 'letrec' is based based on Dan Friedman's code,
;; using the "half-closure" approach from Reynold's definitional
;; interpreters.

(defrel (make-meta-cont-levelo level env)
  (ext-env*o (list 'level) (list level) initial-env env))

(defrel (get-meta-conto level meta-k)
  (fresh (env)
    (make-meta-cont-levelo level env)
    (== meta-k (cons env `(next-meta-cont ,level)))))

(defrel (meta-cont-forceo mc fc)
  (conde
   ((fresh (level)
     (== mc `(next-meta-cont ,level))
     (get-meta-conto `(s ,level) fc)))
   ((fresh (a d)
     (== mc (cons a d))
     (=/= a 'next-meta-cont)
     (== mc fc)))))

(defrel (evalo expr val)
  (fresh (mc)
    (get-meta-conto 'z mc)
    (eval-expo expr initial-env mc val)))

(defrel (eval-expo expr env meta-k val)
  (conde
    ((== `(quote ,val) expr)
     (absent-tago val)
     (not-in-envo 'quote env))

    ((numbero expr) (== expr val))

    ((symbolo expr) (lookupo expr env val))

    ((fresh (x body)
       (== `(lambda ,x ,body) expr)
       (== `(closure (lambda ,x ,body) ,env) val)
       (conde
         ;; Variadic
         ((symbolo x))
         ;; Multi-argument
         ((list-of-symbolso x)))
       (not-in-envo 'lambda env)))

    ((fresh (e r body)
       (== `(mu (,e ,r) ,body) expr)
       (== `(mu-reifier (,e ,r) ,body) val)
       (not-in-envo 'mu env)))

    ((fresh (e r e-res r-res)
       (== `(meaning ,e ,r)  expr)
       (not-in-envo 'meaning env)
       (eval-expo e env meta-k e-res)
       (eval-expo r env meta-k r-res)
       (eval-expo e-res r-res (cons env meta-k) val)))

    ((fresh (rator rands e r body env-res forced-mc upper-env upper-meta-cont)
       (== `(,rator . ,rands) expr)
       (eval-expo rator env meta-k `(mu-reifier (,e ,r) ,body))
       (== forced-mc (cons upper-env upper-meta-cont))
       (ext-env*o (list e r) (list rands env) upper-env env-res)
       (meta-cont-forceo meta-k forced-mc)
       (eval-expo body env-res upper-meta-cont val)))

    ((fresh (rator x rands body env^ a* res)
       (== `(,rator . ,rands) expr)
       ;; variadic
       (symbolo x)
       (== `((,x . (val . ,a*)) . ,env^) res)
       (eval-expo rator env meta-k `(closure (lambda ,x ,body) ,env^))
       (eval-expo body res meta-k val)
       (eval-listo rands env meta-k a*)))

    ((fresh (rator x* rands body env^ a* res)
       (== `(,rator . ,rands) expr)
       ;; Multi-argument
       (eval-expo rator env meta-k `(closure (lambda ,x* ,body) ,env^))
       (eval-listo rands env meta-k a*)
       (ext-env*o x* a* env^ res)
       (eval-expo body res meta-k val)))

    ((fresh (rator x* rands a* prim-id)
       (== `(,rator . ,rands) expr)
       (eval-expo rator env meta-k `(prim . ,prim-id))
       (eval-primo prim-id a* val)
       (eval-listo rands env meta-k a*)))

    ((handle-matcho expr env meta-k val))

    ((fresh (p-name x body letrec-body)
       ;; single-function variadic letrec version
       (== `(letrec ((,p-name (lambda ,x ,body)))
              ,letrec-body)
           expr)
       (conde
         ; Variadic
         ((symbolo x))
         ; Multiple argument
         ((list-of-symbolso x)))
       (not-in-envo 'letrec env)
       (eval-expo letrec-body
                  `((,p-name . (rec . (lambda ,x ,body))) . ,env)
                  meta-k
                  val)))

    ((prim-expo expr env meta-k val))

    ))

(define empty-env '())

(defrel (lookupo x env t)
  (fresh (y b rest)
    (== `((,y . ,b) . ,rest) env)
    (conde
      ((== x y)
       (conde
         ((== `(val . ,t) b))
         ((fresh (lam-expr)
            (== `(rec . ,lam-expr) b)
            (== `(closure ,lam-expr ,env) t)))))
      ((=/= x y)
       (lookupo x rest t)))))

(defrel (not-in-envo x env)
  (conde
    ((== empty-env env))
    ((fresh (y b rest)
       (== `((,y . ,b) . ,rest) env)
       (=/= y x)
       (not-in-envo x rest)))))

(defrel (eval-listo expr env meta-k val)
  (conde
    ((== '() expr)
     (== '() val))
    ((fresh (a d v-a v-d)
       (== `(,a . ,d) expr)
       (== `(,v-a . ,v-d) val)
       (eval-expo a env meta-k v-a)
       (eval-listo d env meta-k v-d)))))

;; need to make sure lambdas are well formed.
;; grammar constraints would be useful here!!!
(defrel (list-of-symbolso los)
  (conde
    ((== '() los))
    ((fresh (a d)
       (== `(,a . ,d) los)
       (symbolo a)
       (list-of-symbolso d)))))

(defrel (ext-env*o x* a* env out)
  (conde
    ((== '() x*) (== '() a*) (== env out))
    ((fresh (x a dx* da* env2)
       (== `(,x . ,dx*) x*)
       (== `(,a . ,da*) a*)
       (== `((,x . (val . ,a)) . ,env) env2)
       (symbolo x)
       (ext-env*o dx* da* env2 out)))))

(defrel (eval-primo prim-id a* val)
  (conde
    [(== prim-id 'cons)
     (fresh (a d)
       (== `(,a ,d) a*)
       (== `(,a . ,d) val))]
    [(== prim-id 'car)
     (fresh (d)
       (== `((,val . ,d)) a*)
       (not-tago val))]
    [(== prim-id 'cdr)
     (fresh (a)
       (== `((,a . ,val)) a*)
       (not-tago a))]
    [(== prim-id 'not)
     (fresh (b)
       (== `(,b) a*)
       (conde
         ((=/= #f b) (== #f val))
         ((== #f b) (== #t val))))]
    [(== prim-id 'equal?)
     (fresh (v1 v2)
       (== `(,v1 ,v2) a*)
       (conde
         ((== v1 v2) (== #t val))
         ((=/= v1 v2) (== #f val))))]
    [(== prim-id 'symbol?)
     (fresh (v)
       (== `(,v) a*)
       (conde
         ((symbolo v) (== #t val))
         ((numbero v) (== #f val))
         ((booleano v) (== #f val))
         ((fresh (a d)
            (== `(,a . ,d) v)
            (== #f val)))))]
    [(== prim-id 'null?)
     (fresh (v)
       (== `(,v) a*)
       (conde
         ((== '() v) (== #t val))
         ((=/= '() v) (== #f val))))]))

(defrel (prim-expo expr env meta-k val)
  (conde
    ((boolean-primo expr env meta-k val))
    ((and-primo expr env meta-k val))
    ((or-primo expr env meta-k val))
    ((if-primo expr env meta-k val))))

(defrel (boolean-primo expr env meta-k val)
  (conde
    ((== #t expr) (== #t val))
    ((== #f expr) (== #f val))))

(defrel (and-primo expr env meta-k val)
  (fresh (e*)
    (== `(and . ,e*) expr)
    (not-in-envo 'and env)
    (ando e* env meta-k val)))

(defrel (ando e* env meta-k val)
  (conde
    ((== '() e*) (== #t val))
    ((fresh (e)
       (== `(,e) e*)
       (eval-expo e env meta-k val)))
    ((fresh (e1 e2 e-rest v)
       (== `(,e1 ,e2 . ,e-rest) e*)
       (conde
         ((== #f v)
          (== #f val)
          (eval-expo e1 env meta-k v))
         ((=/= #f v)
          (eval-expo e1 env meta-mk v)
          (ando `(,e2 . ,e-rest) env meta-k val)))))))

(defrel (or-primo expr env meta-k val)
  (fresh (e*)
    (== `(or . ,e*) expr)
    (not-in-envo 'or env)
    (oro e* env meta-k val)))

(defrel (oro e* env meta-k val)
  (conde
    ((== '() e*) (== #f val))
    ((fresh (e)
       (== `(,e) e*)
       (eval-expo e env meta-k val)))
    ((fresh (e1 e2 e-rest v)
       (== `(,e1 ,e2 . ,e-rest) e*)
       (conde
         ((=/= #f v)
          (== v val)
          (eval-expo e1 env meta-k v))
         ((== #f v)
          (eval-expo e1 env meta-k v)
          (oro `(,e2 . ,e-rest) env meta-k val)))))))

(defrel (if-primo expr env meta-k val)
  (fresh (e1 e2 e3 t)
    (== `(if ,e1 ,e2 ,e3) expr)
    (not-in-envo 'if env)
    (eval-expo e1 env meta-k t)
    (conde
      ((=/= #f t) (eval-expo e2 env meta-k val))
      ((== #f t) (eval-expo e3 env meta-k val)))))

(define initial-env `((list . (val . (closure (lambda x x) ,empty-env)))
                      (not . (val . (prim . not)))
                      (equal? . (val . (prim . equal?)))
                      (symbol? . (val . (prim . symbol?)))
                      (cons . (val . (prim . cons)))
                      (null? . (val . (prim . null?)))
                      (car . (val . (prim . car)))
                      (cdr . (val . (prim . cdr)))
                      . ,empty-env))

(defrel (not-tago val)
  (fresh ()
    (=/= 'closure val)
    (=/= 'prim val)))

(defrel (absent-tago val)
  (fresh ()
    (absento 'closure val)
    (absento 'mu-reifier val)
    (absento 'prim val)))

(defrel (handle-matcho expr env meta-k val)
  (fresh (against-expr mval clause clauses)
    (== `(match ,against-expr ,clause . ,clauses) expr)
    (not-in-envo 'match env)
    (eval-expo against-expr env meta-k mval)
    (match-clauses mval `(,clause . ,clauses) env meta-k val)))

(defrel (not-symbolo t)
  (conde
    ((== '() t))
    ((booleano t))
    ((numbero t))
    ((fresh (a d)
       (== `(,a . ,d) t)))))

(defrel (not-numbero t)
  (conde
    ((== '() t))
    ((booleano t))
    ((symbolo t))
    ((fresh (a d)
       (== `(,a . ,d) t)))))

(defrel (self-eval-literalo t)
  (conde
    ((numbero t))
    ((booleano t))))

(defrel (literalo t)
  (conde
    ((== '() t))
    ((numbero t))
    ((symbolo t) (not-tago t))
    ((booleano t))))

(defrel (booleano t)
  (conde
    ((== #f t))
    ((== #t t))))

(defrel (regular-env-appendo env1 env2 env-out)
  (conde
    ((== empty-env env1) (== env2 env-out))
    ((fresh (y v rest res)
       (== `((,y . (val . ,v)) . ,rest) env1)
       (== `((,y . (val . ,v)) . ,res) env-out)
       (regular-env-appendo rest env2 res)))))

(defrel (match-clauses mval clauses env meta-k val)
  (fresh (p result-expr d penv)
    (== `((,p ,result-expr) . ,d) clauses)
    (conde
      ((fresh (env^)
         (p-match p mval '() penv)
         (regular-env-appendo penv env env^)
         (eval-expo result-expr env^ meta-k val)))
      ((p-no-match p mval '() penv)
       (match-clauses mval d env meta-k val)))))

(defrel (var-p-match var mval penv penv-out)
  (fresh (val)
    (symbolo var)
    (not-tago mval)
    (conde
      ((== mval val)
       (== penv penv-out)
       (lookupo var penv val))
      ((== `((,var . (val . ,mval)) . ,penv) penv-out)
       (not-in-envo var penv)))))

(defrel (var-p-no-match var mval penv penv-out)
  (fresh (val)
    (symbolo var)
    (=/= mval val)
    (== penv penv-out)
    (lookupo var penv val)))

(defrel (p-match p mval penv penv-out)
  (conde
    ((self-eval-literalo p)
     (== p mval)
     (== penv penv-out))
    ((var-p-match p mval penv penv-out))
    ((fresh (var pred val)
      (== `(? ,pred ,var) p)
      (conde
        ((== 'symbol? pred)
         (symbolo mval))
        ((== 'number? pred)
         (numbero mval)))
      (var-p-match var mval penv penv-out)))
    ((fresh (quasi-p)
      (== (list 'quasiquote quasi-p) p)
      (quasi-p-match quasi-p mval penv penv-out)))))

(defrel (p-no-match p mval penv penv-out)
  (conde
    ((self-eval-literalo p)
     (=/= p mval)
     (== penv penv-out))
    ((var-p-no-match p mval penv penv-out))
    ((fresh (var pred val)
       (== `(? ,pred ,var) p)
       (== penv penv-out)
       (symbolo var)
       (conde
         ((== 'symbol? pred)
          (conde
            ((not-symbolo mval))
            ((symbolo mval)
             (var-p-no-match var mval penv penv-out))))
         ((== 'number? pred)
          (conde
            ((not-numbero mval))
            ((numbero mval)
             (var-p-no-match var mval penv penv-out)))))))
    ((fresh (quasi-p)
      (== (list 'quasiquote quasi-p) p)
      (quasi-p-no-match quasi-p mval penv penv-out)))))

(defrel (quasi-p-match quasi-p mval penv penv-out)
  (conde
    ((== quasi-p mval)
     (== penv penv-out)
     (literalo quasi-p))
    ((fresh (p)
      (== (list 'unquote p) quasi-p)
      (p-match p mval penv penv-out)))
    ((fresh (a d v1 v2 penv^)
       (== `(,a . ,d) quasi-p)
       (== `(,v1 . ,v2) mval)
       (=/= 'unquote a)
       (quasi-p-match a v1 penv penv^)
       (quasi-p-match d v2 penv^ penv-out)))))

(defrel (quasi-p-no-match quasi-p mval penv penv-out)
  (conde
    ((=/= quasi-p mval)
     (== penv penv-out)
     (literalo quasi-p))
    ((fresh (p)
       (== (list 'unquote p) quasi-p)
       (not-tago mval)
       (p-no-match p mval penv penv-out)))
    ((fresh (a d)
       (== `(,a . ,d) quasi-p)
       (=/= 'unquote a)
       (== penv penv-out)
       (literalo mval)))
    ((fresh (a d v1 v2 penv^)
       (== `(,a . ,d) quasi-p)
       (=/= 'unquote a)
       (== `(,v1 . ,v2) mval)
       (conde
         ((quasi-p-no-match a v1 penv penv^))
         ((quasi-p-match a v1 penv penv^)
          (quasi-p-no-match d v2 penv^ penv-out)))))))
