--  SPDX-License-Identifier: Apache-2.0
--
--  Instantiations that drive gnatprove analysis of the generic core
--  units. Proof scaffolding only; not part of the shipped library.

with SHACL_Ada.Data;
with SHACL_Ada.Eval;

package SHACL_Ada.Proofs with SPARK_Mode is

   package Proof_Data is new SHACL_Ada.Data (Max_Triples => 32);

   package Proof_Eval is new SHACL_Ada.Eval
     (Max_Violations => 8,
      Data            => Proof_Data);

end SHACL_Ada.Proofs;
