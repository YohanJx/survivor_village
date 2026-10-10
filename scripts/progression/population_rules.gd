class_name PopulationRules
extends RefCounted
## 在稳定身份名册与现有职业人数之间协调，战损优先按战报身份删除。


static func reconcile(state: VillageState) -> void:
	reconcile_progress(state.progress, state.population, state.profession_counts)


static func reconcile_progress(
	progress: VillageProgress, population: int, counts: PackedInt32Array
) -> void:
	var people: Array[SurvivorRecord] = progress.survivors
	while people.size() > population:
		people.pop_back()
	while people.size() < population:
		var person: SurvivorRecord = SurvivorRecord.new()
		person.id = progress.next_person_id
		progress.next_person_id += 1
		people.append(person)
	var remaining: PackedInt32Array = counts.duplicate()
	var unassigned: Array[SurvivorRecord] = []
	for person: SurvivorRecord in people:
		if remaining[person.profession] > 0:
			remaining[person.profession] -= 1
		else:
			unassigned.append(person)
	var index: int = 0
	for profession: int in GameTypes.Profession.COUNT:
		for worker: int in remaining[profession]:
			unassigned[index].profession = profession as GameTypes.Profession
			index += 1


static func surviving_roster(state: VillageState, ids: PackedInt32Array) -> void:
	var people: Array[SurvivorRecord] = []
	var counts: PackedInt32Array = []
	counts.resize(GameTypes.Profession.COUNT)
	for person: SurvivorRecord in state.progress.survivors:
		if ids.has(person.id):
			people.append(person)
			counts[person.profession] += 1
	state.population = people.size()
	state.profession_counts = counts
	state.progress.survivors = people
