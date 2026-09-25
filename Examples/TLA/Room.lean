module

public import Veil

/- Direct translation of Room.tla for model checking comparison.
This version aims to match TLA+ semantics as closely as possible.
-/

veil module RoomMC

-- CONSTANT Room, Guest
enum Room = { Elm, Cendana }
enum Guest = { Olivier, Bruno, Aquinas }

@[veil_decl]
structure Key (Room : Type) where
  room : Room
  num : Nat

set_type GuestSet : Guest
set_type KeySet : Key Room
enum Position = { noroom,  room }
enum Occupied = { nobody, body }


-- VARIABLE assignedKey \in [Guest -> {"noroom", "room"}]
-- VARIABLE registered \in [Room -> SUBSET Guest]
-- VARIABLE roomKey \in [Room -> Key]
-- VARIABLE guestKeys \in [Guest -> SUBSET Key]
-- VARIABLE inside \in [Room -> {"nobody", "body"}]
function assignedKey (g : Guest) : Position
function registered (r : Room) : GuestSet
function roomKey (r : Room) : Key Room
function guestKeys (g : Guest) : KeySet
function inside (r : Room) : Occupied

#gen_state

-- Init == /\ assignedKey = [g \in Guest |-> "noroom"]
--         /\ registered = [r \in Room |-> {}]
--         /\ roomKey = [r \in Room |-> <<r,0>>]
--         /\ guestKeys = [r \in Guest |-> {}]
--         /\ inside = [r \in Room |-> "nobody"]
after_init {
  assignedKey G := noroom
  registered R := ∅
  roomKey R := { room := R, num := 0 }
  guestKeys G := ∅
  inside R := nobody
}

-- ghost relation constr

-- CheckIn(g,r) == /\ Cardinality(registered[r]) = 0
--                 /\ registered' = [registered EXCEPT ![r] = registered[r] \cup {g}]
--                 /\ guestKeys' = [guestKeys EXCEPT ![g] = guestKeys[g] \cup {roomKey[r]}]
--                 /\ UNCHANGED <<assignedKey,roomKey,inside>>
action CheckIn (g : Guest) (r : Room) {
  require ∀gx, card (guestKeys gx) <= 3
  require registered r = ∅
  registered r := insert g (registered r)
  guestKeys g := insert (roomKey r) (guestKeys g)
}


-- CheckOut(g,r) == /\ g \in registered[r]
--                  /\ assignedKey[g] = "noroom"
--                  /\ inside[r] = "nobody"
--                  /\ registered' = [registered EXCEPT ![r] = registered[r] \ {g}]
--                  /\ roomKey' = [roomKey EXCEPT ![r] = NextKey(r, roomKey[r])]
--                  /\ UNCHANGED <<assignedKey,guestKeys,inside>>
action CheckOut (g : Guest) (r : Room) {
  require ∀gx, card (guestKeys gx) <= 3
  require g ∈ registered r
  require assignedKey g = noroom
  require inside r = nobody
  registered r := registered r \ {g}
  -- roomKey' = [roomKey EXCEPT ![r] = NextKey(r, roomKey[r])]
  -- NextKey(r, k) = <<r, k[2]+1>>
  let currentKey := roomKey r
  let nextNum := currentKey.num + 1
  roomKey r := { room := r, num := nextNum }
}

-- EnterRoom(g,r) == /\ assignedKey[g] = "noroom"
--                   /\ inside[r] = "nobody"
--                   /\ Cardinality(guestKeys[g]) > 0
--                   /\ roomKey[r] = RandomElement(guestKeys[g])  -- KEY CONSTRAINT!
--                   /\ assignedKey' = [assignedKey EXCEPT ![g] = "room"]
--                   /\ inside' = [inside EXCEPT ![r] = "body"]
--                   /\ UNCHANGED <<registered,roomKey,guestKeys>>
action EnterRoom (g : Guest) (r : Room) {
  require ∀gx, card (guestKeys gx) <= 3
  require assignedKey g = noroom
  require inside r = nobody
  require card (guestKeys g) > 0
  -- roomKey[r] = RandomElement(guestKeys[g])
  require roomKey r ∈ (guestKeys g)
  assignedKey g := room
  inside r := body
}

-- LeaveRoom(g,r) == /\ assignedKey[g] = "room"
--                   /\ inside[r] = "body"
--                   /\ \E k \in guestKeys[g] : k = roomKey[r]
--                   /\ assignedKey' = [assignedKey EXCEPT ![g] = "noroom"]
--                   /\ inside' = [inside EXCEPT ![r] = "nobody"]
--                   /\ UNCHANGED <<registered,roomKey,guestKeys>>
action LeaveRoom (g : Guest) (r : Room) {
  require ∀gx, card (guestKeys gx) <= 3
  require assignedKey g = room
  require inside r = body
  require (roomKey r) ∈ (guestKeys g)
  assignedKey g := noroom
  inside r := nobody
}

-- -- NoBadEntry invariants
-- -- 1. \A r \in Room : Cardinality(registered[r]) <= 1
safety [registered_at_most_one]
  ∀ r, card (registered r) ≤ 1

-- -- 2. assignedKey[g] = "room" => \E r \in Room :
-- --        /\ roomKey[r] \in guestKeys[g]
-- --        /\ inside[r] = "body"
-- --        /\ g \in registered[r]
safety [guest_in_room_valid]
  ∀ g, assignedKey g = room →
    ∃ r, roomKey r ∈ guestKeys g ∧
         inside r = body ∧
         g ∈ registered r

-- -- 3. inside[r] = "body" => \E g \in Guest :
-- --        /\ roomKey[r] \in guestKeys[g]
-- --        /\ assignedKey[g] = "room"
-- --        /\ g \in registered[r]
safety [room_occupied_valid]
  ∀ r, inside r = body →
    ∃ g, roomKey r ∈ guestKeys g ∧
         assignedKey g = room ∧
         g ∈ registered r

invariant [key_num] ∀ R, (roomKey R).num < 10
#gen_spec

#model_check
{
  -- seq_t := Fin 11,
  Room := Room_IndT,
  Guest := Guest_IndT,
  Position := Position_IndT,
  Occupied := Occupied_IndT
}
{ }
  (maxDepth := 2) (sequential := true)

end RoomMC
