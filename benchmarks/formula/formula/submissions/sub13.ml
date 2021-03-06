type formula = TRUE
| FALSE
| NOT of formula
| ANDALSO of formula * formula
| ORELSE of formula * formula
| IMPLY of formula * formula
| LESS of expr * expr
and expr = NUM of int
| PLUS of expr * expr
| MINUS of expr * expr

let rec check expr=
    match expr with
     |NUM a-> a
	 |PLUS (a,b)-> (check expr)+(check expr)
	 |MINUS (a,b)->(check expr)-(check expr)

let rec eval form=
	match form with
	|TRUE -> true
	|FALSE -> false
	|NOT a-> eval a
	|ANDALSO (a,b)-> (eval a) && (eval b)
	|ORELSE (a,b)-> (eval a) || (eval b)
	|IMPLY (a,b)-> eval (ORELSE (NOT a, b))
	|LESS (a,b)-> (check a)<(check b)
