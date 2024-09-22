/****************************************************
				INTERNAL ORGANS
****************************************************/
/obj/item/organ/internal
	parent_bodypart = BP_CHEST


	// Will be moved, removed or refactored.
	var/process_accuracy = 0    // Damage multiplier for organs, that have damage values.
	// 0 - normal
	// 1 - assisted
	// 2 - mechanical

/obj/item/organ/internal/New(var/mob/living/carbon/holder)
	if(istype(holder))
		insert_organ(holder)
	..()

/obj/item/organ/internal/Destroy()
	if(parent)
		parent.bodypart_organs -= src
		parent = null
	if(owner)
		owner.organs -= src
		if(owner.organs_by_name[organ_tag] == src)
			owner.organs_by_name -= organ_tag
	return ..()

/obj/item/organ/internal/remove(mob/living/carbon/human/M, special = 0)
	owner = null
	STOP_PROCESSING(SSobj, src)
	if(M)
		M.organs -= src
		if(M.organs_by_name[organ_tag] == src)
			M.organs_by_name -= organ_tag
		if(M.internal_organs_slot[slot] == src)
			M.internal_organs_slot.Remove(slot)

		if(vital && !special)
			if(M.stat != DEAD)//safety check!
				M.death()

	if(istype(M, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = M
		var/obj/item/organ/external/parent = H.get_organ(check_zone(parent_bodypart))
		if(!istype(parent))
			return
		else
			parent.bodypart_organs -= src

/obj/item/organ/internal/insert_organ(mob/living/carbon/human/H, surgically = FALSE, datum/species/S)
	..()

	var/obj/item/organ/internal/replaced = H.get_organ_slot(slot)
	if(replaced)
		replaced.remove(H, special = 1)

	owner.organs += src
	owner.organs_by_name[organ_tag] = src
	H.internal_organs_slot[slot] = src

	if(parent)
		parent.bodypart_organs += src

/obj/item/organ/internal/replaced(var/mob/living/carbon/human/target,var/obj/item/organ/external/affected)
    insert_organ(target)
    ..()

/obj/item/organ/internal/proc/rejuvenate()
	damage = 0

/obj/item/organ/internal/proc/is_bruised()
	return damage >= min_bruised_damage

/obj/item/organ/internal/proc/is_broken()
	return damage >= min_broken_damage

/obj/item/organ/internal/proc/on_life()
	return

/obj/item/organ/internal/process()
	//Process infections

	if (robotic >= 2 || (owner.species && owner.species.flags[IS_PLANT]))	//TODO make robotic organs and bodyparts separate types instead of a flag
		germ_level = 0
		return

	if(owner.bodytemperature >= 170)	//cryo stops germs from moving and doing their bad stuffs
		//** Handle antibiotics and curing infections
		handle_antibiotics()

		//** Handle the effects of infections
		var/antibiotics = owner.reagents.get_reagent_amount("spaceacillin")

		if (germ_level > 0 && germ_level < INFECTION_LEVEL_ONE/2 && prob(30))
			germ_level--

		if (germ_level >= INFECTION_LEVEL_ONE/2)
			//aiming for germ level to go from ambient to INFECTION_LEVEL_TWO in an average of 15 minutes
			if(antibiotics < 5 && prob(round(germ_level/6)))
				germ_level++

		if (germ_level >= INFECTION_LEVEL_TWO)
			var/obj/item/organ/external/BP = owner.bodyparts_by_name[parent_bodypart]
			//spread germs
			if (antibiotics < 5 && BP.germ_level < germ_level && ( BP.germ_level < INFECTION_LEVEL_ONE * 2 || prob(30) ))
				BP.germ_level++

			if (prob(3))	//about once every 30 seconds
				take_damage(1,silent=prob(30))



/obj/item/organ/internal/emp_act(severity)
	switch(robotic)
		if(0)
			return
		if(1)
			switch (severity)
				if (1.0)
					take_damage(20,0)
					return
				if (2.0)
					take_damage(7,0)
					return
				if(3.0)
					take_damage(3,0)
					return
		if(2)
			switch (severity)
				if (1.0)
					take_damage(40,0)
					return
				if (2.0)
					take_damage(15,0)
					return
				if(3.0)
					take_damage(10,0)
					return

/obj/item/organ/internal/proc/mechanize() //Being used to make robutt hearts, etc
	robotic = 2

/obj/item/organ/internal/proc/mechassist() //Used to add things like pacemakers, etc
	robotic = 1
	min_bruised_damage = 15
	min_broken_damage = 35

/****************************************************
				ORGANS DEFINES
****************************************************/

/obj/item/organ/internal/heart
	name = "heart"
	icon_state = "heart-on"
	cases = list("сердце", "сердца", "сердцу", "сердце", "сердцем", "сердце")
	organ_tag = O_HEART
	vital = TRUE
	parent_bodypart = BP_CHEST
	var/heart_status = HEART_NORMAL
	var/fibrillation_timer_id = null
	var/failing_interval = 1 MINUTE
	var/beating = 0

/obj/item/organ/internal/heart/update_icon()
	if(beating)
		icon_state = "heart-on"
	else
		icon_state = "heart-off"

/obj/item/organ/internal/heart/insert_organ(mob/living/carbon/M, special = 0)
	..()
	beating = 1
	update_icon()
	owner.metabolism_factor.AddModifier("Heart", multiple = 1.0)


/obj/item/organ/internal/heart/proc/heart_stop()
	if(!owner.reagents.has_reagent("inaprovaline") || owner.stat == DEAD)
		heart_status = HEART_FAILURE
		deltimer(fibrillation_timer_id)
		fibrillation_timer_id = null
		owner.metabolism_factor.AddModifier("Heart", multiple = 0.0)
	else
		take_damage(1, 0)
		fibrillation_timer_id = addtimer(CALLBACK(src, PROC_REF(heart_stop)), 10 SECONDS, TIMER_UNIQUE|TIMER_STOPPABLE)

/obj/item/organ/internal/heart/remove(mob/living/carbon/M, special = 0)
	..()
	heart_status = HEART_FAILURE
	spawn(120)
		beating = 0
		update_icon()


/obj/item/organ/internal/heart/proc/heart_fibrillate()
	heart_status = HEART_FIBR
	if(HAS_TRAIT(owner, TRAIT_FAT))
		failing_interval = 30 SECONDS
	fibrillation_timer_id = addtimer(CALLBACK(src, PROC_REF(heart_stop)), failing_interval, TIMER_UNIQUE|TIMER_STOPPABLE)
	owner.metabolism_factor.AddModifier("Heart", multiple = 0.5)

/obj/item/organ/internal/heart/proc/heart_normalize()
	heart_status = HEART_NORMAL
	deltimer(fibrillation_timer_id)
	fibrillation_timer_id = null
	owner.metabolism_factor.AddModifier("Heart", multiple = 1.0)

/obj/item/organ/internal/heart/ipc
	name = "cooling pump"
	cases = list("помпа системы охлаждения", "помпы системы охлаждения", "помпе системы охлаждения", "помпу системы охлаждения", "помпой системы охлаждения", "помпой системы охлаждения")

	var/pumping_rate = 5
	var/bruised_loss = 3
	requires_robotic_bodypart = TRUE

/obj/item/organ/internal/heart/ipc/process()
	if(owner.nutrition < 1)
		return
	if(is_broken())
		return

	var/obj/item/organ/internal/lungs/ipc/lungs = owner.organs_by_name[O_LUNGS]
	if(!istype(lungs))
		return

	var/pumping_volume = pumping_rate
	if(is_bruised())
		pumping_volume -= bruised_loss

	if(pumping_volume > 0)
		lungs.add_refrigerant(pumping_volume)

/obj/item/organ/internal/heart/vox
	icon = 'icons/obj/special_organs/vox.dmi'
	parent_bodypart = BP_GROIN

/obj/item/organ/internal/heart/tajaran
	icon = 'icons/obj/special_organs/tajaran.dmi'

/obj/item/organ/internal/heart/unathi
	icon = 'icons/obj/special_organs/unathi.dmi'

/obj/item/organ/internal/heart/skrell
	icon = 'icons/obj/special_organs/skrell.dmi'

/obj/item/organ/internal/lungs
	name = "lungs"
	cases = list("лёгкие", "лёгких", "лёгким", "лёгкие", "лёгкими", "лёгких")
	icon_state = "lungs"
	organ_tag = O_LUNGS
	parent_bodypart = BP_CHEST
	slot = "lungs"
	var/has_gills = FALSE

/obj/item/organ/internal/lungs/vox
	name = "air capillary sack"
	cases = list("воздушно-капиллярный мешок", "воздушно-капиллярного мешка", "воздушно-капиллярному мешку", "воздушно-капиллярный мешок", "воздушно-капиллярным мешком", "воздушно-капиллярном мешке")
	parent_bodypart = BP_GROIN
	icon = 'icons/obj/special_organs/vox.dmi'

/obj/item/organ/internal/lungs/tajaran
	icon = 'icons/obj/special_organs/tajaran.dmi'

/obj/item/organ/internal/lungs/unathi
	icon = 'icons/obj/special_organs/unathi.dmi'

/obj/item/organ/internal/lungs/skrell
	name = "respiration sac"
	cases = list("дыхательная сумка", "дыхательной сумки", "дыхательной сумке", "дыхательную сумку", "дыхательной сумкой", "дыхательной сумке")
	has_gills = TRUE
	icon = 'icons/obj/special_organs/skrell.dmi'

/obj/item/organ/internal/lungs/diona
	name = "virga inopinatus"
	cases = list("полая ветка", "полой ветки", "полой ветки", "полую ветку", "полой веткой", "полой ветке")
	process_accuracy = 10

/obj/item/organ/internal/lungs/ipc
	name = "cooling element"
	cases = list("охлаждающий элемент", "охлаждающего элемента", "охлаждающему элементу", "охлаждающий элемент", "охлаждающим элементом", "охлаждающем элементе")

	var/refrigerant_max = 50
	var/refrigerant = 50
	var/refrigerant_rate = 5
	var/bruised_loss = 3
	requires_robotic_bodypart = TRUE

/obj/item/organ/internal/lungs/process()
	..()
	if (owner.species && owner.species.flags[NO_BREATHE])
		return
	if (germ_level > INFECTION_LEVEL_ONE)
		if(!owner.reagents.has_reagent("dextromethorphan") && prob(5))
			owner.emote("cough")		//respitory tract infection

	if(is_bruised())
		if(prob(2))
			owner.emote("cough")
			owner.drip(10)
		if(prob(4)  && !HAS_TRAIT(owner, TRAIT_AV))
			owner.emote("gasp")
			owner.losebreath += 15

/obj/item/organ/internal/lungs/ipc/process()
	if(owner.nutrition < 1)
		return
	var/temp_gain = owner.species.synth_temp_gain

	if(refrigerant > 0 && !is_broken())
		var/refrigerant_spent = refrigerant_rate
		refrigerant -= refrigerant_rate
		if(refrigerant < 0)
			refrigerant_spent += refrigerant
			refrigerant = 0

		if(is_bruised())
			refrigerant_spent -= bruised_loss

		if(refrigerant_spent > 0)
			temp_gain -= refrigerant_spent

	if(HAS_TRAIT(owner, TRAIT_COOLED) & owner.bodytemperature > 290)
		owner.adjust_bodytemperature(-50)

	if(temp_gain > 0)
		owner.adjust_bodytemperature(temp_gain, max_temp = owner.species.synth_temp_max)

/obj/item/organ/internal/lungs/ipc/proc/add_refrigerant(volume)
	if(refrigerant < refrigerant_max)
		refrigerant += volume
		if(refrigerant > refrigerant_max)
			refrigerant = refrigerant_max

/obj/item/organ/internal/liver
	name = "liver"
	cases = list("печень", "печени", "печени", "печень", "печенью", "печени")
	icon_state = "liver"
	organ_tag = O_LIVER
	parent_bodypart = BP_GROIN
	slot = "liver"
	process_accuracy = 10

/obj/item/organ/internal/liver/diona
	name = "chlorophyll sac"
	cases = list("хлорофилловый мешок", "хлорофиллового мешка", "хлорофилловому мешку", "хлорофилловый мешок", "хлорофилловым мешком", "хлорофилловом мешке")

/obj/item/organ/internal/liver/vox
	name = "waste tract"
	cases = list("канал отходов", "канала отходов", "каналу отходов", "канал отходов", "каналом отходов", "канале отходов")
	icon = 'icons/obj/special_organs/vox.dmi'

/obj/item/organ/internal/liver/tajaran
	icon = 'icons/obj/special_organs/tajaran.dmi'

/obj/item/organ/internal/liver/unathi
	icon = 'icons/obj/special_organs/unathi.dmi'

/obj/item/organ/internal/liver/skrell
	icon = 'icons/obj/special_organs/skrell.dmi'

/obj/item/organ/internal/liver/ipc
	name = "accumulator"
	cases = list("аккумулятор", "аккумулятора", "аккумулятору", "аккумулятор", "аккумулятором", "аккумуляторе")
	var/accumulator_warning = 0
	requires_robotic_bodypart = TRUE

/obj/item/organ/internal/liver/ipc/set_owner(mob/living/carbon/human/H, datum/species/S)
	..()
	new/obj/item/weapon/stock_parts/cell/crap(src)
	RegisterSignal(owner, COMSIG_ATOM_ELECTROCUTE_ACT, PROC_REF(ipc_cell_explode))

/obj/item/organ/internal/liver/proc/handle_liver_infection()
	if(germ_level > INFECTION_LEVEL_ONE)
		if(prob(1))
			to_chat(owner, "<span class='warning'>Your skin itches.</span>")
	if(germ_level > INFECTION_LEVEL_TWO)
		if(prob(1))
			INVOKE_ASYNC(owner, TYPE_PROC_REF(/mob/living/carbon/human, vomit))

/obj/item/organ/internal/liver/proc/handle_liver_life()
	if(owner.life_tick % process_accuracy != 0)
		return

	if(src.damage < 0)
		src.damage = 0

	//High toxins levels are dangerous
	if(owner.getToxLoss() >= 60 && !owner.reagents.has_reagent("anti_toxin"))
		//Healthy liver suffers on its own
		if (src.damage < min_broken_damage)
			src.damage += 0.2 * process_accuracy
		//Damaged one shares the fun
		else
			var/obj/item/organ/internal/IO = pick(owner.organs)
			if(IO)
				IO.damage += 0.2 * process_accuracy

	//Detox can heal small amounts of damage
	if (src.damage && src.damage < src.min_bruised_damage && owner.reagents.has_reagent("anti_toxin"))
		src.damage -= 0.2 * process_accuracy

	// Damaged liver means some chemicals are very dangerous
	if(src.damage >= src.min_bruised_damage)
		for(var/datum/reagent/R in owner.reagents.reagent_list)
			// Ethanol and all drinks are bad
			if(istype(R, /datum/reagent/consumable/ethanol))
				owner.adjustToxLoss(0.1 * process_accuracy)
			// Can't cope with toxins at all
			if(istype(R, /datum/reagent/toxin))
				owner.adjustToxLoss(0.3 * process_accuracy)

/obj/item/organ/internal/liver/process()
	..()
	handle_liver_infection()
	handle_liver_life()

/obj/item/organ/internal/liver/serpentid

/obj/item/organ/internal/liver/serpentid/handle_liver_life()
	if(is_bruised())
		if(owner.life_tick % process_accuracy == 0)
			for(var/datum/reagent/R in owner.reagents.reagent_list)
				if(istype(R, /datum/reagent/consumable/ethanol))
					owner.adjustToxLoss(0.1 * process_accuracy)
				if(istype(R, /datum/reagent/toxin))
					owner.adjustToxLoss(0.3 * process_accuracy)
		owner.adjustOxyLoss(damage)

	if(owner.reagents.get_reagent_amount("dexalinp") >= 4.0)
		return
	owner.reagents.add_reagent("dexalinp", REAGENTS_METABOLISM * 1.5)

	if(owner.reagents.get_reagent_amount("dexalinp") >= 3.0)
		return
	damage += 0.2

/obj/item/organ/internal/liver/ipc/process()
	var/obj/item/weapon/stock_parts/cell/C = locate(/obj/item/weapon/stock_parts/cell) in src

	if(!C)
		if(!owner.is_bruised_organ(O_KIDNEYS) && prob(2))
			to_chat(owner, "<span class='warning bold'>%ACCUMULATOR% DAMAGED BEYOND FUNCTION. SHUTTING DOWN.</span>")
		owner.SetParalysis(2)
		owner.blurEyes(2)
		owner.silent = 2
		return
	if(damage)
		C.charge = owner.nutrition
		if(owner.nutrition > (C.maxcharge - damage * 5))
			owner.nutrition = C.maxcharge - damage * 5
	if(owner.nutrition < 1)
		owner.SetParalysis(2)
		if(accumulator_warning < world.time)
			to_chat(owner, "<span class='warning bold'>%ACCUMULATOR% LOW CHARGE. SHUTTING DOWN.</span>")
			accumulator_warning = world.time + 15 SECONDS

/obj/item/organ/internal/liver/ipc/proc/ipc_cell_explode()
	var/obj/item/weapon/stock_parts/cell/C = locate() in src
	if(!C)
		return
	var/turf/T = get_turf(owner.loc)
	if(owner.nutrition > (C.maxcharge * 1.2))
		explosion(T, 0, 1, 2)
		C.ex_act(EXPLODE_DEVASTATE)

/obj/item/organ/internal/kidneys
	name = "kidneys"
	cases = list("почки", "почек", "почкам", "почки", "почками", "почках")
	icon_state = "kidneys"
	organ_tag = O_KIDNEYS
	parent_bodypart = BP_GROIN
	slot = "kidneys"

/obj/item/organ/internal/kidneys/vox
	name = "filtration bladder"
	cases = list("фильтрующий пузырь", "фильтрующего пузыря", "фильтрующему пузырю", "фильтрующий пузырь", "фильтрующим пузырём", "фильтрующем пузыре")
	icon = 'icons/obj/special_organs/vox.dmi'

/obj/item/organ/internal/kidneys/tajaran
	icon = 'icons/obj/special_organs/tajaran.dmi'

/obj/item/organ/internal/kidneys/unathi
	icon = 'icons/obj/special_organs/unathi.dmi'

/obj/item/organ/internal/kidneys/skrell
	icon = 'icons/obj/special_organs/skrell.dmi'

/obj/item/organ/internal/kidneys/diona
	name = "vacuole"
	cases = list("вакуоль", "вакуоли", "вакуолям", "вакуоль", "вакуолью", "вакуоли")
	parent_bodypart = BP_GROIN

/obj/item/organ/internal/kidneys/ipc
	name = "self-diagnosis unit"
	cases = list("устройство самодиагностики", "устройства самодиагностики", "устройству самодиагностики", "устройство самодиагностики", "устройством самодиагностики", "устройстве самодиагностики")
	parent_bodypart = BP_GROIN

	var/next_warning = 0
	requires_robotic_bodypart = TRUE

/obj/item/organ/internal/kidneys/process()

	..()

	if(!owner)
		return

	// Coffee is really bad for you with busted kidneys.
	// This should probably be expanded in some way, but fucked if I know
	// what else kidneys can process in our reagent list.
	var/datum/reagent/coffee = locate(/datum/reagent/consumable/drink/coffee) in owner.reagents.reagent_list
	if(coffee)
		if(is_bruised())
			owner.adjustToxLoss(0.1 * process_accuracy)
		else if(is_broken())
			owner.adjustToxLoss(0.3 * process_accuracy)


/obj/item/organ/internal/kidneys/ipc/process()
	if(owner.nutrition < 1)
		return
	if(next_warning > world.time)
		return
	next_warning = world.time + 10 SECONDS

	var/damage_report = ""
	var/first = TRUE

	for(var/obj/item/organ/internal/IO in owner.organs)
		if(IO.is_bruised())
			if(!first)
				damage_report += "\n"
			first = FALSE
			damage_report += "<span class='warning'><b>%[uppertext(IO.name)]%</b> INJURY DETECTED. CEASE DAMAGE TO <b>%[uppertext(IO.name)]%</b>. REQUEST ASSISTANCE.</span>"

	if(damage_report != "")
		to_chat(owner, damage_report)

/obj/item/organ/internal/brain
	name = "brain"
	cases = list("мозг", "мозга", "мозгу", "мозг", "мозгом", "мозге")
	organ_tag = O_BRAIN
	vital = TRUE
	parent_bodypart = O_BRAIN
	slot = "brain"

/obj/item/organ/internal/brain/diona
	name = "main node nymph"
	cases = list("главная нимфа", "главной нимфы", "главной нимфе", "главную нимфу", "главной нимфой", "главной нимфе")
	parent_bodypart = BP_CHEST

/obj/item/organ/internal/brain/tajaran
	icon = 'icons/obj/special_organs/tajaran.dmi'

/obj/item/organ/internal/brain/unathi
	icon = 'icons/obj/special_organs/unathi.dmi'

/obj/item/organ/internal/brain/vox
	icon = 'icons/obj/special_organs/vox.dmi'

/obj/item/organ/internal/brain/skrell
	icon = 'icons/obj/special_organs/skrell.dmi'

/obj/item/organ/internal/brain/ipc
	name = "positronic brain"
	cases = list("позитронный мозг", "позитронного мозга", "позитронному мозгу", "позитронный мозг", "позитронным мозгом", "позитронном мозге")
	parent_bodypart = BP_CHEST
	requires_robotic_bodypart = TRUE

/obj/item/organ/internal/brain/abomination
	name = "deformed brain"
	cases = list("деформированный мозг", "деформированного мозга", "деформированному мозгу", "деформированный мозг", "деформированным мозгом", "деформированном мозге")
	parent_bodypart = BP_CHEST

/obj/item/organ/internal/eyes
	name = "eyes"
	icon_state = "eyes"
	cases = list("глаза", "глаз", "глазам", "глаза", "глазами", "глазах")
	organ_tag = O_EYES
	parent_bodypart = BP_HEAD
	slot = "eyes"
	var/list/eye_colour = list(0,0,0)

/obj/item/organ/internal/eyes/proc/update_colour()
	if(!owner)
		return
	eye_colour = list(
		owner.r_eyes ? owner.r_eyes : 0,
		owner.g_eyes ? owner.g_eyes : 0,
		owner.b_eyes ? owner.b_eyes : 0
		)

/obj/item/organ/internal/eyes/insert_organ(mob/living/carbon/human/M, special = 0)
// Apply our eye colour to the target.
	if(istype(M) && eye_colour)
		var/mob/living/carbon/human/eyes = M
		eyes.r_eyes = eye_colour[1]
		eyes.g_eyes = eye_colour[2]
		eyes.b_eyes = eye_colour[3]
		eyes.update_eyes()
	..()

/mob/living/carbon/human/proc/update_eyes()
	var/obj/item/organ/internal/eyes/eyes = get_int_organ(/obj/item/organ/internal/eyes)
	if(eyes)
		eyes.update_colour()
		regenerate_icons()

/obj/item/organ/internal/eyes/tajaran
	icon = 'icons/obj/special_organs/tajaran.dmi'

/obj/item/organ/internal/eyes/unathi
	icon = 'icons/obj/special_organs/unathi.dmi'

/obj/item/organ/internal/eyes/vox
	icon = 'icons/obj/special_organs/vox.dmi'

/obj/item/organ/internal/eyes/skrell
	icon = 'icons/obj/special_organs/skrell.dmi'

/obj/item/organ/internal/eyes/ipc
	name = "cameras"
	cases = list("камеры", "камер", "камерам", "камеры", "камерами", "камерах")
	robotic = 2
	requires_robotic_bodypart = TRUE

/obj/item/organ/internal/eyes/process() //Eye damage replaces the old eye_stat var.
	..()
	if(is_bruised())
		owner.blurEyes(20)
	if(is_broken())
		owner.eye_blind = 20
