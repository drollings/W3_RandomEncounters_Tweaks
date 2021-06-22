
state Wandering in RandomEncountersReworkedHuntingGroundEntity {
  event OnEnterState(previous_state_name: name) {
    super.OnEnterState(previous_state_name);

    LogChannel('modRandomEncounters', "RandomEncountersReworkedHuntingGroundEntity - State Wandering");
    this.Wandering_main();
  }

  entry function Wandering_main() {
    this.resetEntitiesActions();
    this.makeEntitiesMoveTowardsBait();
    this.resetEntitiesActions();

    parent.GotoState('Combat');
  }

  latent function makeEntitiesMoveTowardsBait() {
    var distance_from_player: float;
    var distance_from_bait: float;
    var current_entity: CEntity;
    var current_heading: float;
    var i: int;

    do {
      if (parent.areAllEntitiesDead()) {
        LogChannel('modRandomEncounters', "HuntingGroundEntity - wandering state, all entities dead");

        parent.GotoState('Ending');

        break;
      }

      // in case it moves
      parent.bait_entity.Teleport(parent.GetWorldPosition());

      SUH_keepCreaturesOnPoint(
        parent.GetWorldPosition(),
        25,
        parent.entities,
      );

      for (i = parent.entities.Size() - 1; i >= 0; i -= 1) {
        current_entity = parent.entities[i];

        distance_from_player = VecDistance(
          current_entity.GetWorldPosition(),
          thePlayer.GetWorldPosition()
        );

        // when in bounty mode, creatures are not subject to the kill threshold distance
        if (!parent.is_bounty && distance_from_player > parent.entity_settings.kill_threshold_distance) {
          LogChannel('modRandomEncounters', "killing entity - threshold distance reached: " + parent.entity_settings.kill_threshold_distance);

          parent.killEntity(current_entity);

          continue;
        }

        if (distance_from_player < 15
        || distance_from_player < 20 && ((CActor)current_entity).HasAttitudeTowards(thePlayer)) {
          // leave the function, it will automatically enter in the Combat state
          // and the creatures will attack the player.
          return;
        }

        distance_from_bait = VecDistanceSquared(
          current_entity.GetWorldPosition(),
          parent.bait_entity.GetWorldPosition()
        );

        if (distance_from_bait > 20 * 20) {
          ((CActor)parent.entities[i]).SetTemporaryAttitudeGroup(
            'monsters',
            AGP_Default
          );

          ((CActor)current_entity).ActionCancelAll();

          ((CNewNPC)current_entity)
            .NoticeActor((CActor)parent.bait_entity);
        }
      }

      Sleep(3);
    } while (true);
  }

  // Checks if one of the creatures is outside the given point and its radius
  // and teleports it back into the circle  ifthe creature is indeed outside.
  // The function is supposed to be called in a fast while loop to keep the
  // creatures on point in an efficient way.
  function keepCreaturesOnPoint(position: Vector, radius: float) {
    var distance_from_point: float;
    var old_position: Vector;
    var new_position: Vector;
    var i: int;

    for (i = 0; i < parent.entities.Size(); i += 1) {
      old_position = parent.entities[i].GetWorldPosition();

      distance_from_point = VecDistanceSquared(
        old_position,
        position
      );

      if (distance_from_point > radius) {
        new_position = VecInterpolate(
          old_position,
          position,
          1 / radius
        );

        FixZAxis(new_position);

        if (new_position.Z < old_position.Z) {
          new_position.Z = old_position.Z;
        }

        parent
          .entities[i]
          .Teleport(new_position);
      }
    }
  }

  latent function resetEntitiesActions() {
    var i: int;
    var current_entity: CEntity;
    
    for (i = parent.entities.Size() - 1; i >= 0; i -= 1) {
      current_entity = parent.entities[i];

      ((CActor)current_entity).ActionCancelAll();

      ((CActor)current_entity)
          .GetMovingAgentComponent()
          .ResetMoveRequests();

      ((CActor)current_entity)
          .GetMovingAgentComponent()
          .SetGameplayMoveDirection(0.0f);
    }
  }
}
