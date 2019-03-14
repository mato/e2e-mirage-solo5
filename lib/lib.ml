open Shexp_process
open Shexp_process.Infix

let run_path = "./run"
let switch_path = run_path ^ "/switch"
let src_path = "./unikernel"
let block_path = run_path ^ "/disk.img"
let universe_path = "./universe"

(* setup the base switch, creating a "cache" of it in switch.tar.gz, this is
 * useful for repeated runs mainly while developing this script, to save on
 * time taken to build ocaml *)
let setup_switch = 
    file_exists switch_path >>= function
    | true  ->
      call [ "rm"; "-rf"; switch_path ]
      >> call [ "mkdir"; "-p"; switch_path ]
      >> chdir switch_path (call [ "tar"; "-xzf"; "../switch.tar.gz" ])
    | false ->
      call [ "mkdir"; "-p"; switch_path ]
      >> call [ "opam"; "switch"; "create"; switch_path; "4.07.1" ]
      >> chdir switch_path (call [ "tar"; "-czf"; "../switch.tar.gz"; "." ])

type pin_action = Master | Release | Local

let universe : (string * pin_action) list =
  let u = eval (readdir universe_path) in
  Stdlib.List.map (fun pkg ->
    let pkgdir = eval (readdir (universe_path ^ "/" ^ pkg)) in
    match pkgdir with
    | [ "master" ] -> (pkg, Master)
    | [ "release" ] -> (pkg, Release)
    | [ "local" ] -> (pkg, Local)
    | _ -> raise (Failure "bad definition"))
    u

let abspath path = call [ "readlink"; "-f"; path ] |- read_all >>| String.trim

(* the eval expression will be evaluated immediately, so we can't use (abspath
 * switch_path) here as it might not exist yet *)
let with_switch = [ "opam"; "exec";
                    "--switch=" ^ (eval (abspath ".")) ^ "/" ^ switch_path;
                    "--set-switch"; "--" ]

let opam_install args =
  set_env "OPAMYES" "true" (call (with_switch @ [ "opam"; "install" ] @ args))

let opam_pin_action (pkg, action) =
  match action with
  | Master -> (* pin package to --dev-repo *)
    set_env "OPAMYES" "true" (
      call (with_switch @ [ "opam"; "pin"; "add"; "-n"; "--dev-repo"; pkg ]))
  | Local -> (* pin package to local repo at universe/pkg/local *)
    set_env "OPAMYES" "true" (
      call (with_switch @ [ "opam"; "pin"; "add"; "-n"; pkg;
                            universe_path ^ "/" ^ pkg ^ "/local" ]))
  | Release -> (* install but don't pin, i.e. use the released version *)
    return ()

let install_mirage =
  Shexp_process.List.iter ~f:opam_pin_action universe
  >> opam_install (Stdlib.List.map (fun (pkg, _) -> pkg) universe)

let build_unikernel =
  chdir src_path (
    call (with_switch @ [ "mirage"; "configure"; "-t"; "hvt" ])
    >> call (with_switch @ [ "make"; "depend" ])
    >> call (with_switch @ [ "make" ])
  )

let setup_net =
  let ip args = call ([ "sudo"; "ip" ] @ args) in
  file_exists "/sys/class/net/tap100" >>= function
  | true  -> return ()
  | false -> ip [ "tuntap"; "add"; "tap100"; "mode"; "tap" ]
             >> ip [ "addr"; "add"; "10.0.0.1/24"; "dev"; "tap100" ]
             >> ip [ "link"; "set"; "dev"; "tap100"; "up" ]

let setup_block =
  file_exists block_path >>= function
  | true  -> return ()
  | false ->
    call [ "dd"; "if=/dev/zero"; "of=" ^ block_path; "bs=512"; "count=1" ]

let init_unikernel =
  call [ src_path ^ "/solo5-hvt";
         "--net=tap100";
         "--disk=" ^ block_path;
         src_path ^ "/test.hvt"; "--init" ]

