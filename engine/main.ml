open Lang
open Print
open Options

exception Arg_exception

let usage_msg = "main.native -run (or -fix) -submission <filename> -solution <filename>"

let parse_file (f:string) : (examples * prog) =
  Preproc.preprocess_file f
    |> Lexing.from_string
    |> Parser.prog Lexer.token

let program_with_grading prog = prog@(External.grading_prog)

let program_with_input prog inputs =
  let res_var = "__res__" in
  prog @ [(DLet (BindOne res_var,false,[],fresh_tvar(),(Lang.appify (EVar !opt_entry_func) inputs)))] 

let except_handling : exn -> value -> unit
= fun except output ->
  begin match except with
  |EExcept v ->
    print_endline("Result : " ^ Print.value_to_string v ^ " " ^
                  "Expected: " ^ Print.value_to_string output);
  |TimeoutError ->
    print_endline("Result : Timeout" ^ " " ^
                  "Expected: " ^ Print.value_to_string output);
  |Failure s ->
    print_endline("Result : Error "^ s ^ " " ^
                  "Expected: " ^ Print.value_to_string output);
  |_ ->
     print_endline("Result : Evaluation Error "^
                  "Expected: " ^ Print.value_to_string output);
  end
 
let run_testcases : prog -> examples -> unit
=fun prog examples ->
  let score = List.fold_left (fun score (inputs, output) ->
    let prog = program_with_grading prog in
    let prog' = program_with_input prog inputs in
    let _ = Type.run prog' in
    try
      let env = Eval.run prog' in
      let result_value = Lang.lookup_env "__res__" env in
        print_endline ("Result: " ^ Print.value_to_string result_value ^ " " ^  
                     "Expected: " ^ Print.value_to_string output);
        if(result_value=output) then score+1 else score
    with except -> except_handling except output; score
  ) 0 examples in
  print_endline("score : "^(string_of_int score))

let run_prog : prog -> examples -> unit
=fun prog examples ->
  let _ = Type.run prog in
  print_header "Program"; Print.print_pgm prog;
  print_header "Test-cases"; print_examples examples;
  print_header "Run test-cases"; run_testcases prog examples 

let fix_with_solution : prog -> prog -> examples -> unit
=fun submission solution examples ->
  let _ = Type.run submission in
  let score = Util.list_fold (fun (inputs, output) score->
    let submission = program_with_grading submission in
    let prog = program_with_input submission inputs in
    let _ = 
      try
        (Type.run prog)
      with |_ -> raise (Failure "The submission and type are mismatched")
    in
    try
      let env = Eval.run prog in
      let result_value = Lang.lookup_env "__res__" env in
      if(result_value=output) then score+1 else score
    with |_ -> score
  ) examples 0 in
  let _ = if(score=List.length examples) then raise (Failure "The submission is correct code") in
  let ranked_prog_set = Localize.localization submission examples in
  let initial_set = BatSet.map
   (
      fun (n,prog)->
        let (_,hole_type,variable_type) = Type.run prog in
        (n,prog,hole_type,variable_type)
    ) ranked_prog_set in
  let components = Comp.extract_component solution in
  ignore (Synthesize.hole_synthesize submission initial_set components examples)
 
let execute : prog -> unit
=fun prog ->
  let (tenv,_,_) = Type.run prog in
  let env = Eval.run prog in
  (Print.print_REPL prog tenv env)

let read_prog : string -> prog option
=fun filename ->
  try 
    if Sys.file_exists filename then Some (snd (parse_file filename)) 
    else None 
  with _ -> raise (Failure ("parsing error: " ^ filename)) 

let main () = 
  let _ = Arg.parse options (fun s->()) usage_msg in
  let testcases = 
    if !opt_testcases_filename = "" then [] 
    else try fst (parse_file !opt_testcases_filename) 
         with _ -> raise (Failure ("error during parsing testcases: " ^ !opt_testcases_filename)) in 
  let submission = read_prog !opt_submission_filename in
  let solution = read_prog !opt_solution_filename in
    match !opt_run, !opt_fix, !opt_execute with
    | true, false, false -> (* execution mode *)
      begin
        match submission with
        | Some sub -> run_prog sub testcases
        | _ -> raise (Failure (!opt_submission_filename ^ " does not exist"))
      end
    | false, true, false -> (* fix mode *)
      begin
        match submission, solution with
        | Some sub, Some sol -> fix_with_solution sub sol testcases 
        | Some sub, None -> raise (Failure ("You should input the solution to fix the program"))
        | _ -> raise (Failure (!opt_submission_filename ^ " does not exist"))
      end
    | false, false, true -> (* execution mode *)
      begin 
        match submission with
        | Some sub -> execute sub
        | _ -> raise (Failure "Submission file is not provided")
      end
    | _ -> Arg.usage options usage_msg

let _ = main ()
