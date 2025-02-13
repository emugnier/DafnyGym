/*******************************************************************************
 *  Copyright by the contributors to the Dafny Project
 *  SPDX-License-Identifier: MIT
 *******************************************************************************/

module Loops {
  import Monad
  import Quantifier
  import Independence
  import Rand

  /************
   Definitions
  ************/

  // Definition 37
  function WhileCut<A>(condition: A -> bool, body: A -> Monad.Hurd<A>, init: A, fuel: nat): Monad.Hurd<A> {
    if fuel == 0 || !condition(init) then
      Monad.Return(init)
    else
      Monad.Bind(body(init), (init': A) => WhileCut(condition, body, init', fuel - 1))
  }

  ghost predicate WhileCutTerminates<A>(condition: A -> bool, body: A -> Monad.Hurd<A>, init: A, s: Rand.Bitstream) {
    exists fuel: nat :: WhileCutTerminatesWithFuel(condition, body, init, s)(fuel)
  }

  ghost function WhileCutTerminatesWithFuel<A>(condition: A -> bool, body: A -> Monad.Hurd<A>, init: A, s: Rand.Bitstream): nat -> bool {
    (fuel: nat) => !WhileCut(condition, body, init, fuel)(s).Satisfies(condition)
  }

  // Definition 39 / True iff Prob(iset s | While(condition, body, a)(s) terminates) == 1
  ghost predicate WhileTerminatesAlmostSurely<A(!new)>(condition: A -> bool, body: A -> Monad.Hurd<A>) {
    var p := (init: A) =>
               (s: Rand.Bitstream) => WhileCutTerminates(condition, body, init, s);
    forall init :: Quantifier.AlmostSurely(p(init))
  }

  // Definition of while loops.
  // This definition is opaque because the details are not very useful.
  // For proofs, use the lemma `WhileUnroll`.
  // Equation (3.25), but modified to use `Monad.Diverging` instead of HOL's `arb` in case of nontermination
  opaque ghost function While<A(!new)>(condition: A -> bool, body: A -> Monad.Hurd<A>): (loop: A -> Monad.Hurd<A>)
    ensures forall s: Rand.Bitstream, init: A :: !condition(init) ==> loop(init)(s) == Monad.Return(init)(s)
  {
    var f :=
      (init: A) =>
        (s: Rand.Bitstream) =>
          if WhileCutTerminates(condition, body, init, s)
          then
            var fuel := LeastFuel(condition, body, init, s);
            WhileCut(condition, body, init, fuel)(s)
          else
            Monad.Diverging;
    assert forall s: Rand.Bitstream, init: A :: !condition(init) ==> f(init)(s) == Monad.Return(init)(s) by {
      forall s: Rand.Bitstream, init: A ensures !condition(init) ==> f(init)(s) == Monad.Return(init)(s) {
        if !condition(init) {
          assert WhileCutTerminatesWithFuel(condition, body, init, s)(0);
        }
      }
    }
    f
  }

  ghost function LeastFuel<A>(condition: A -> bool, body: A -> Monad.Hurd<A>, init: A, s: Rand.Bitstream): (fuel: nat)
    requires WhileCutTerminates(condition, body, init, s)
    ensures WhileCutTerminatesWithFuel(condition, body, init, s)(fuel)
    ensures forall fuel': nat :: WhileCutTerminatesWithFuel(condition, body, init, s)(fuel') ==> fuel <= fuel'
  {
    var fuelBound :| WhileCutTerminatesWithFuel(condition, body, init, s)(fuelBound);
    Least(WhileCutTerminatesWithFuel(condition, body, init, s), fuelBound)
  }

  ghost function Least(property: nat -> bool, bound: nat, start: nat := 0): (l: nat)
    decreases bound - start
    requires start <= bound
    requires property(bound)
    ensures property(l)
    ensures start <= l <= bound
    ensures forall n: nat | start <= n :: property(n) ==> l <= n
  {
    if start == bound || property(start)
    then start
    else Least(property, bound, start + 1)
  }

  ghost predicate UntilTerminatesAlmostSurely<A(!new)>(proposal: Monad.Hurd<A>, accept: A -> bool) {
    var reject := (a: A) => !accept(a);
    var body := (a: A) => proposal;
    WhileTerminatesAlmostSurely(reject, body)
  }

  // Definition of until loops (rejection sampling).
  // For proofs, use the lemma `UntilUnroll`.
  // Definition 44
  ghost function Until<A(!new)>(proposal: Monad.Hurd<A>, accept: A -> bool): (f: Monad.Hurd<A>)
    requires UntilTerminatesAlmostSurely(proposal, accept)
    ensures
      var reject := (a: A) => !accept(a);
      var body := (a: A) => proposal;
      forall s :: f(s) == proposal(s).Bind(While(reject, body))
  {
    var reject := (a: A) => !accept(a);
    var body := (a: A) => proposal;
    Monad.Bind(proposal, While(reject, body))
  }

  function WhileLoopExitsAfterOneIteration<A(!new)>(body: A -> Monad.Hurd<A>, condition: A -> bool, init: A): (Rand.Bitstream -> bool) {
    (s: Rand.Bitstream) =>
      body(init)(s).Satisfies(v => !condition(v))
  }

  function ProposalIsAccepted<A(!new)>(proposal: Monad.Hurd<A>, accept: A -> bool): (Rand.Bitstream -> bool) {
    (s: Rand.Bitstream) =>
      proposal(s).Satisfies(accept)
  }

  ghost function UntilLoopResultIsAccepted<A(!new)>(proposal: Monad.Hurd<A>, accept: A -> bool): (Rand.Bitstream -> bool)
    requires UntilTerminatesAlmostSurely(proposal, accept)
  {
    (s: Rand.Bitstream) => Until(proposal, accept)(s).Satisfies(accept)
  }

  ghost function UntilLoopResultHasProperty<A(!new)>(proposal: Monad.Hurd<A>, accept: A -> bool, property: A -> bool): iset<Rand.Bitstream>
    requires UntilTerminatesAlmostSurely(proposal, accept)
  {
    iset s | Until(proposal, accept)(s).Satisfies(property)
  }

  ghost function ProposalIsAcceptedAndHasProperty<A>(proposal: Monad.Hurd<A>, accept: A -> bool, property: A -> bool): iset<Rand.Bitstream>
  {
    iset s | proposal(s).Satisfies(property) && proposal(s).Satisfies(accept)
  }

  ghost function ProposalAcceptedEvent<A>(proposal: Monad.Hurd<A>, accept: A -> bool): iset<Rand.Bitstream>
  {
    iset s | proposal(s).Satisfies(accept)
  }


  /*******
   Lemmas
  *******/

  lemma LeastFuelUnroll<A>(condition: A -> bool, body: A -> Monad.Hurd<A>, init: A, s: Rand.Bitstream, init': A, s': Rand.Bitstream, fuel': nat)
    requires WhileCutTerminates(condition, body, init', s')
    requires LeastFuel(condition, body, init', s') == fuel'
    requires condition(init)
    requires body(init)(s) == Monad.Result(init', s')
    ensures WhileCutTerminates(condition, body, init, s)
    ensures LeastFuel(condition, body, init, s) == fuel' + 1
  {
    assert WhileCutTerminates(condition, body, init, s) by {
      WhileCutTerminatesWithFuelUnroll(condition, body, init, s, init', s', fuel');
    }
    var fuel := LeastFuel(condition, body, init, s);
    assert fuel == fuel' + 1 by {
      WhileCutTerminatesWithFuelUnroll(condition, body, init, s, init', s', fuel');
      WhileCutTerminatesWithFuelUnroll(condition, body, init, s, init', s', fuel - 1);
    }
  }

  lemma WhileCutUnroll<A>(condition: A -> bool, body: A -> Monad.Hurd<A>, init: A, s: Rand.Bitstream, init': A, s': Rand.Bitstream, fuel: nat)
    requires condition(init)
    requires body(init)(s) == Monad.Result(init', s')
    ensures WhileCut(condition, body, init, fuel + 1)(s) == WhileCut(condition, body, init', fuel)(s')
  {}


  lemma WhileCutTerminatesWithFuelUnroll<A>(condition: A -> bool, body: A -> Monad.Hurd<A>, init: A, s: Rand.Bitstream, init': A, s': Rand.Bitstream, fuel: nat)
    requires condition(init)
    requires body(init)(s) == Monad.Result(init', s')
    ensures WhileCutTerminatesWithFuel(condition, body, init, s)(fuel + 1) == WhileCutTerminatesWithFuel(condition, body, init', s')(fuel)
  {}

  lemma WhileCutTerminatesUnroll<A>(condition: A -> bool, body: A -> Monad.Hurd<A>, init: A, s: Rand.Bitstream, init': A, s': Rand.Bitstream)
    requires condition(init)
    requires body(init)(s) == Monad.Result(init', s')
    ensures WhileCutTerminates(condition, body, init, s) == WhileCutTerminates(condition, body, init', s')
  {
    if WhileCutTerminates(condition, body, init, s) {
      var fuel: nat :| WhileCutTerminatesWithFuel(condition, body, init, s)(fuel);
      WhileCutTerminatesWithFuelUnroll(condition, body, init, s, init', s', fuel - 1);
    }
    if WhileCutTerminates(condition, body, init', s') {
      var fuel: nat :| WhileCutTerminatesWithFuel(condition, body, init', s')(fuel);
      WhileCutTerminatesWithFuelUnroll(condition, body, init, s, init', s', fuel);
    }
  }

  lemma WhileUnrollIfConditionSatisfied<A>(condition: A -> bool, body: A -> Monad.Hurd<A>, init: A, s: Rand.Bitstream, init': A, s': Rand.Bitstream, loop: Monad.Result<A>, unrolled: Monad.Result<A>)
    requires WhileCutTerminates(condition, body, init, s)
    requires condition(init)
    requires body(init)(s) == Monad.Result(init', s')
    requires loop == While(condition, body)(init)(s)
    requires unrolled == While(condition, body)(init')(s')
    ensures loop == unrolled
  {
    var fuel: nat := LeastFuel(condition, body, init, s);
    assert fuel >= 1;
    var fuel': nat := fuel - 1;
    assert WhileCutTerminatesWithFuel(condition, body, init', s')(fuel');
    assert WhileCutTerminates(condition, body, init', s');
    var minFuel: nat := LeastFuel(condition, body, init', s');
    assert minFuel == fuel' by {
      LeastFuelUnroll(condition, body, init, s, init', s', minFuel);
    }
    assert loop == unrolled by {
      calc {
        loop;
        { reveal While(); }
        WhileCut(condition, body, init, fuel)(s);
        { WhileCutUnroll(condition, body, init, s, init', s', fuel'); }
        WhileCut(condition, body, init', fuel')(s');
        { reveal While(); }
        unrolled;
      }
    }
  }

  lemma WhileUnrollIfTerminates<A(!new)>(condition: A -> bool, body: A -> Monad.Hurd<A>, init: A, s: Rand.Bitstream, fuel: nat, loop: Monad.Result<A>, unrolled: Monad.Result<A>)
    requires WhileCutTerminates(condition, body, init, s)
    requires fuel == LeastFuel(condition, body, init, s)
    requires loop == While(condition, body)(init)(s)
    requires unrolled == (if condition(init) then Monad.Bind(body(init), While(condition, body)) else Monad.Return(init))(s)
    ensures loop == unrolled
  {
    if condition(init) {
      assert fuel >= 1;
      match body(init)(s)
      case Diverging =>
        calc {
          loop;
          { reveal While(); }
          WhileCut(condition, body, init, fuel)(s);
          Monad.Diverging;
          unrolled;
        }
      case Result(init', s') =>
        calc {
          loop;
          { WhileUnrollIfConditionSatisfied(condition, body, init, s, init', s', loop, unrolled); }
          While(condition, body)(init')(s');
          unrolled;
        }
    } else {
      calc {
        loop;
        Monad.Result(init, s);
        unrolled;
      }
    }
  }

  lemma WhileUnrollIfDiverges<A>(condition: A -> bool, body: A -> Monad.Hurd<A>, init: A, s: Rand.Bitstream, loop: Monad.Result<A>, unrolled: Monad.Result<A>)
    requires !WhileCutTerminates(condition, body, init, s)
    requires loop == While(condition, body)(init)(s)
    requires unrolled == (if condition(init) then Monad.Bind(body(init), While(condition, body)) else Monad.Return(init))(s)
    ensures loop == unrolled == Monad.Diverging
  {
    reveal While();
    match body(init)(s)
    case Diverging =>
      assert unrolled == Monad.Diverging;
    case Result(init', s') =>
      assert !WhileCutTerminates(condition, body, init', s') by {
        WhileCutTerminatesUnroll(condition, body, init, s, init', s');
      }
  }

  // Theorem 38
  lemma WhileUnroll<A(!new)>(condition: A -> bool, body: A -> Monad.Hurd<A>, init: A, s: Rand.Bitstream)
    requires WhileTerminatesAlmostSurely(condition, body)
    ensures While(condition, body)(init)(s) == (if condition(init) then Monad.Bind(body(init), While(condition, body)) else Monad.Return(init))(s)
  {
    var loop := While(condition, body)(init)(s);
    var unrolled := (if condition(init) then Monad.Bind(body(init), While(condition, body)) else Monad.Return(init))(s);
    assert loop == unrolled by {
      if WhileCutTerminates(condition, body, init, s) {
        var fuel: nat := LeastFuel(condition, body, init, s);
        WhileUnrollIfTerminates(condition, body, init, s, fuel, loop, unrolled);
      } else {
        WhileUnrollIfDiverges(condition, body, init, s, loop, unrolled);
      }
    }
  }

  lemma EnsureUntilTerminates<A(!new)>(proposal: Monad.Hurd<A>, accept: A -> bool)
    requires Independence.IsIndep(proposal)
    requires Quantifier.WithPosProb((s: Rand.Bitstream) => proposal(s).Satisfies(accept))
    ensures UntilTerminatesAlmostSurely(proposal, accept)
  {
    var reject := (a: A) => !accept(a);
    var body := (a: A) => proposal;
    var proposalIsAccepted := (s: Rand.Bitstream) => proposal(s).Satisfies(accept);
    assert UntilTerminatesAlmostSurely(proposal, accept) by {
      forall a: A ensures Independence.IsIndep(body(a)) {
        assert body(a) == proposal;
      }
      forall a: A ensures Quantifier.WithPosProb(WhileLoopExitsAfterOneIteration(body, reject, a)) {
        assert Quantifier.WithPosProb(proposalIsAccepted);
              }
      assert WhileTerminatesAlmostSurely(reject, body) by {
        EnsureWhileTerminates(reject, body);
      }
    }
  }

  // (Equation 3.30) / Sufficient conditions for while-loop termination
  lemma {:axiom} EnsureWhileTerminates<A(!new)>(condition: A -> bool, body: A -> Monad.Hurd<A>)
    requires forall a :: Independence.IsIndep(body(a))
    requires forall a :: Quantifier.WithPosProb(WhileLoopExitsAfterOneIteration(body, condition, a))
    ensures WhileTerminatesAlmostSurely(condition, body)

  // Theorem 45 (wrong!) / PROB_BERN_UNTIL (correct!)
  lemma {:axiom} UntilProbabilityFraction<A>(proposal: Monad.Hurd<A>, accept: A -> bool, d: A -> bool)
    requires Independence.IsIndep(proposal)
    requires Quantifier.WithPosProb(ProposalIsAccepted(proposal, accept))
    ensures UntilTerminatesAlmostSurely(proposal, accept)
    ensures
      && UntilLoopResultHasProperty(proposal, accept, d) in Rand.eventSpace
      && ProposalIsAcceptedAndHasProperty(proposal, accept, d) in Rand.eventSpace
      && ProposalAcceptedEvent(proposal, accept) in Rand.eventSpace
      && Rand.prob(ProposalAcceptedEvent(proposal, accept)) != 0.0
      && Rand.prob(UntilLoopResultHasProperty(proposal, accept, d)) == Rand.prob(ProposalIsAcceptedAndHasProperty(proposal, accept, d)) / Rand.prob(ProposalAcceptedEvent(proposal, accept))

  // Equation (3.39)
  lemma UntilUnroll<A(!new)>(proposal: Monad.Hurd<A>, accept: A -> bool, s: Rand.Bitstream)
    requires Independence.IsIndep(proposal)
    requires UntilTerminatesAlmostSurely(proposal, accept)
    ensures Until(proposal, accept)(s) == Monad.Bind(proposal, (x: A) => if accept(x) then Monad.Return(x) else Until(proposal, accept))(s)
  {
    var reject := (a: A) => !accept(a);
    var body := (a: A) => proposal;
    match proposal(s)
    case Diverging =>
    case Result(init, s') => WhileUnroll(reject, body, init, s');
  }

  // Equation (3.40)
  lemma EnsureUntilTerminatesAndForAll<A(!new)>(proposal: Monad.Hurd<A>, accept: A -> bool)
    requires Independence.IsIndep(proposal)
    requires Quantifier.WithPosProb(ProposalIsAccepted(proposal, accept))
    ensures UntilTerminatesAlmostSurely(proposal, accept)
    ensures Quantifier.AlmostSurely(UntilLoopResultIsAccepted(proposal, accept))
  {
    EnsureUntilTerminates(proposal, accept);
    assume {:axiom} Quantifier.AlmostSurely(UntilLoopResultIsAccepted(proposal, accept)); // add later
  }

  lemma WhileCutIsIndep<A(!new)>(condition: A -> bool, body: A -> Monad.Hurd<A>, init: A, fuel: nat)
    requires forall a: A :: Independence.IsIndep(body(a))
    ensures Independence.IsIndep(WhileCut(condition, body, init, fuel))
  {
    if fuel == 0 || !condition(init) {
      Independence.ReturnIsIndep(init);
    } else {
      forall init': A ensures Independence.IsIndep(WhileCut(condition, body, init', fuel - 1)) {
        WhileCutIsIndep(condition, body, init', fuel - 1);
      }
      Independence.BindIsIndep(body(init), init' => WhileCut(condition, body, init', fuel - 1));
    }
  }

  lemma WhileIsIndep<A(!new)>(condition: A -> bool, body: A -> Monad.Hurd<A>, init: A)
    requires forall a: A :: Independence.IsIndep(body(a))
    requires WhileTerminatesAlmostSurely(condition, body)
    ensures Independence.IsIndep(While(condition, body)(init))
  {
    // To prove this, we need a definition of Independence.IsIndep
    assume {:axiom} false;
  }

  lemma UntilIsIndep<A(!new)>(proposal: Monad.Hurd<A>, accept: A -> bool)
    requires Independence.IsIndep(proposal)
    requires UntilTerminatesAlmostSurely(proposal, accept)
    ensures Independence.IsIndep(Until(proposal, accept))
  {
    var reject := (a: A) => !accept(a);
    var body := (a: A) => proposal;
    forall init: A ensures Independence.IsIndep(While(reject, body)(init)) {
      WhileIsIndep(reject, body, init);
    }
    Independence.BindIsIndep(proposal, While(reject, body));
  }
}
