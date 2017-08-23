(* Copyright 2017 Rigetti Computing, Inc.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*)

module M = Owl.Dense.Matrix.C
open Primitives

let kron_up = List.fold_left M.kron (M.ones 1 1)

let int_pow base exp = (float_of_int base) ** (float_of_int exp) |> int_of_float

let rec binary_rep x =
  let rem = x mod 2 in
  if x > 0 then rem :: binary_rep (x / 2)
  else []

let rec pad_list n l =
  let pl = l@[0] in
  if List.length pl <= n then pad_list n pl
  else l

let rec range i j =
  if i < j then i :: range (i + 1) j
  else []

let build_gate_list n q g =
  let rec _build_list i n q g =
    let x = i + 1 in
    if i <> q && i < n then
      id :: _build_list x n q g
    else if i = q && i < n then
      g :: _build_list x n q g
    else [] in
  _build_list 0 n q g

let build_gate_list_with_2q_gate n ql g =
  let rec _build_nn_2q_gate_list i n ql g =
    let x = i + 1 in
    if ql < n - 1 then
      if i <> ql && i < n then
        id :: _build_nn_2q_gate_list x n ql g
      else if i = ql && i < n - 1 then
        g :: _build_nn_2q_gate_list (x + 1) n ql g
      else []
    else
      if i <> n - 2 && i < n - 1 then
        id :: _build_nn_2q_gate_list x n ql g
      else if (i = n - 2 ) && (i < n) then
        g :: []
      else [] in
  _build_nn_2q_gate_list 0 n ql g

let swapagator ctrl trgt nqubit =
  (* to compute the swapagator first construct a padding of identities to
   * the left of [ctrl] then build the swapagator kernel of distance
   * (trgt - ctrl) and finally pad more identities to the right of [trgt] to
   * fill up to the number of qubits in the qvm. Finally we kron up the
   * resulting list to get the full swapagator. *)
  let _swapagator_kernel dist =
    let _multi_dot dim = List.fold_left M.dot (M.eye (int_pow 2 dim)) in
    let rec _swapagator_sub_kernels i dist =
      let x = i + 1 in
      (* We need to account for the fact that we have a 2-Qubit gate already.
       * Hence when constructing the list of propagators we make the distance
       * short by one as we already have a lifted gate. E.g. a given swapagator
       * for 4 particles is:
       *        [(kron swap id id) * (kron id swap id) * (kron id id swap)],
       * which is of dimension 16. We can construct the individual lists by
       * using the build_gate_list func where the qubit indicates the position
       * of the pair, leading to the reduction by 1 in length of the lists. *)
      if i < dist-1 then
        (kron_up (build_gate_list (dist-1) i swap)) ::
          (_swapagator_sub_kernels x dist)
      else [] in
    (* multiply all individual nearest neighbor SWAPs to propagate a qubit state
     * over a distance [dist]*)
    _multi_dot dist (_swapagator_sub_kernels 0 dist) in
  if ctrl < trgt then
    kron_up ((build_gate_list (ctrl + 1) ctrl id) (* pad left *)
               @[(_swapagator_kernel (trgt - ctrl))] (* swap kernel *)
               @(build_gate_list (nqubit - trgt - 1) trgt id)) (* pad right *)
  else
    (* if ctrl > trgt we need an additional swap *)
    kron_up ((build_gate_list trgt trgt id)
               @[(_swapagator_kernel (ctrl - trgt + 1))]
               @(build_gate_list (nqubit - ctrl - 1) ctrl id))

let get_1q_gate n q g =
  kron_up (build_gate_list n q g)

let get_2q_gate n ctrl trgt g =
  let swpgtr = swapagator ctrl trgt n in
  let gt =
    if ctrl < trgt then
      kron_up (build_gate_list_with_2q_gate n ctrl g)
    else
      kron_up (build_gate_list_with_2q_gate n trgt g) in
  M.dot (M.transpose swpgtr) (M.dot gt swpgtr)

let flip x arr =
  let bit_flip b = (1 - b) in
  arr.(x) <- bit_flip arr.(x);
  arr

let cand x y arr =
  let bit_and ctr tar = if ctr = 1 && tar = 1 then 1 else 0 in
  arr.(y) <-  bit_and arr.(x) arr.(y);
  arr

let cor x y arr =
  let bit_or ctr tar = if ctr = 0 && tar = 0 then 0 else 1 in
  arr.(y) <- bit_or arr.(x) arr.(y);
  arr

let xor x y arr =
  let bit_xor ctr tar = if ctr = tar then 0 else 1 in
  arr.(y) <- bit_xor arr.(x) arr.(y);
  arr
