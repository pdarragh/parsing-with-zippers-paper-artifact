(*

Helpers for writing benchmarks.

Used by only `main.ml`

Copied almost exactly from: https://github.com/janestreet/core_bench/blob/master/src/bench.ml

*)

open Core
open Core_bench

let load_measurements ~filenames =
    List.map ~f:(fun filename -> Bench.Measurement.load ~filename) filenames

let analyze_and_display ~measurements ?analysis_configs ?display_config () =
    let results = List.map ~f:(Bench.analyze ?analysis_configs) measurements in
    let results = List.filter_map results ~f:(fun state -> match state with
        | Error err ->
            printf "Error %s
%!" (Error.to_string_hum err);
            None
        | Ok r -> Some r) in
    Bench.display ?display_config results

let make_bench_command (benchmarks : Bench.Test.t list) =
    fun (analysis_configs, display_config, args) -> match args with
        | (`Run (save_to_file, run_config)) ->
            Bench.bench
                ~analysis_configs
                ~display_config
                ~run_config
                ?save_to_file
                benchmarks
        | (`From_file filenames) ->
            let measurements = load_measurements ~filenames in
            analyze_and_display ~measurements ~analysis_configs:(analysis_configs) ~display_config:(display_config) ()
