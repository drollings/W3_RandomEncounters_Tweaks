
state Processing in RER_HordeManager {
  event OnEnterState(previous_state_name: name) {
    super.OnEnterState(previous_state_name);

    NLOG("RER_HordeManager - Processing");

    this.Processing_main();
  }

  entry function Processing_main() {
    var bestiary_entry: RER_BestiaryEntry;
    var creature_to_spawn: CreatureType;
    var number_of_requests: int;
    var old_number_of_requests: int;
    var total_of_creatures_to_spawn: float;
    var dead_entities: float;
    var i: int;

    while (true) {
      Sleep(RandRange(5, 10));

      number_of_requests = parent.requests.Size();

      // a request was removed or a new one was added
      if (old_number_of_requests != number_of_requests) {
        total_of_creatures_to_spawn = this.getCreaturesCountToSpawnFromRequests(parent.requests);
      }

      old_number_of_requests = number_of_requests;

      if (number_of_requests <= 0) {
        SU_hideCustomBossBar();

        Sleep(2);
        parent.GotoState('Waiting');

        return;
      }

      // the horde monsters are spawned only if regular monsters can be spawned
      if (parent.master.rExtra.isPlayerInSettlement(50)) {
        continue;
      }

      for (i = 0; i < number_of_requests; i += 1) {
        creature_to_spawn = this.getFirstCreatureWithPositiveCounter(parent.requests[i]);

        // we display the title only for the first request in the queue
        if (i == 0 && creature_to_spawn != CreatureNONE) {
          SU_showCustomBossBar(StrReplace(
            GetLocStringByKey("rer_horde_invasion_strength_title"),
            "{{creature_name}}",
            getCreatureNameFromCreatureType(
              parent.master.bestiary,
              creature_to_spawn
            )
          ), true);

          // we also check for a random dialogue here because we know it's ran
          // once.
          if (RandRange(100) > 95) {
            (new RER_RandomDialogBuilder in thePlayer)
              .start()
              .either(new REROL_and_one_more in thePlayer, true, 0.5)
              .either(new REROL_another_one in thePlayer, true, 0.5)
              .play();
          }
        }
        
        dead_entities += SUH_removeDeadEntities(parent.requests[i].entities);
        SU_setCustomBossBarPercent(1 - dead_entities / total_of_creatures_to_spawn);
        SUH_makeEntitiesTargetPlayer(parent.requests[i].entities);

        bestiary_entry = parent.master.bestiary.getEntry(parent.master, creature_to_spawn);
        if (creature_to_spawn == CreatureNONE
        &&  SUH_areAllEntitiesDead(parent.requests[i].entities)) {
          parent.requests[i].onComplete(parent.master);
          parent.requests.EraseFast(i);

          i -= 1;
          number_of_requests -= 1;
        }
        // we do not spawn more creatures if already 25% of the total creatures
        // are in the world at the moment.
        else if (parent.requests[i].entities.Size() < total_of_creatures_to_spawn * (0.3 - bestiary_entry.ecosystem_delay_multiplier * 0.01)) {
          this.spawnMonsterFromRequest(parent.requests[i], creature_to_spawn);
        }

      }
    }
  }

  latent function spawnMonsterFromRequest(request: RER_HordeRequest, creature_to_spawn: CreatureType) {
    var bestiary_entry: RER_BestiaryEntry;
    var position: Vector;
    var entities: array<CEntity>;
    var count: int;
    var i: int;

    if (!getRandomPositionBehindCamera(position)) {
      return;
    }

    bestiary_entry = parent.master.bestiary.getEntry(parent.master, creature_to_spawn);

    count = Min(
      request.counters_per_creature_types[creature_to_spawn],
      RandRange(1, 3)
    );

    entities = bestiary_entry
      .spawn(
        parent.master,
        position,
        count,,
        EncounterType_CONTRACT,
        RER_flag(RER_BESF_NO_TROPHY, !parent.master.settings.trophies_enabled_by_encounter[EncounterType_CONTRACT])
        | RER_BESF_NO_PERSIST
      );

    for (i = 0; i < entities.Size(); i += 1) {
      request.entities.PushBack(entities[i]);
      request.counters_per_creature_types[creature_to_spawn] -= 1;
    }
  }

  function getFirstCreatureWithPositiveCounter(request: RER_HordeRequest): CreatureType {
    var i: int;

    for (i = 0; i < CreatureMAX; i += 1) {
      if (request.counters_per_creature_types[i] > 0) {
        return i;
      }
    }

    return CreatureNONE;
  }

  function getCreaturesCountToSpawnFromRequest(request: RER_HordeRequest): int {
    var count: int;
    var i: int;

    for (i = 0; i < CreatureMAX; i += 1) {
      count += request.counters_per_creature_types[i];
    }

    return count;
  }

  function getCreaturesCountToSpawnFromRequests(requests: array<RER_HordeRequest>): int {
    var count: int;
    var i: int;

    for (i = 0; i < requests.Size(); i += 1) {
      count += this.getCreaturesCountToSpawnFromRequest(requests[i]);
    }

    return count;
  }
}