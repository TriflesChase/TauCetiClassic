/mob/living/carbon/human
	var/list/obj/item/organ/external/bodyparts = list()
	var/list/obj/item/organ/external/bodyparts_by_name = list()
	var/list/obj/item/organ/internal/organs = list()
	var/list/obj/item/organ/internal/organs_by_name = list()

/obj/item/organ
	name = "organ"
	icon = 'icons/obj/surgery.dmi'
	item_state_world
	germ_level = 0

	var/organ_tag = O_HEART
	appearance_flags = TILE_BOUND | PIXEL_SCALE | KEEP_APART | APPEARANCE_UI_IGNORE_ALPHA

	// Strings.
	var/parent_bodypart                // Bodypart holding this object.

	// Status tracking.
	var/status = 0                     // Various status flags (such as robotic)
	var/vital                          // Lose a vital organ, die immediately.

	// Reference data.
	var/mob/living/carbon/human/owner  // Current mob owning the organ.
	var/list/autopsy_data = list()     // Trauma data for forensics.
	var/list/trace_chemicals = list()  // Traces of chemicals in the organ.
	var/obj/item/organ/external/parent // Master-limb.

	// Damage vars.
	var/damage = 0 // amount of damage to the organ
	var/min_bruised_damage = 10
	var/min_broken_damage = 30
	var/max_damage

	var/dead_icon

	var/sterile = 0 //can the organ be infected by germs?
	var/requires_robotic_bodypart = FALSE
	var/slot = "heart"
	// DO NOT add slots with matching names to different zones - it will break internal_organs_slot list!

/obj/item/organ/Destroy()
	owner = null
	return ..()

/obj/item/organ/proc/remove(mob/living/user,special = 0)
	if(!istype(owner))
		return

	owner.organs -= src

	loc = get_turf(owner)
	STOP_PROCESSING(SSobj, src)

	if(owner && vital) // I'd do another check for species or whatever so that you couldn't "kill" an IPC by removing a human head from them, but it doesn't matter since they'll come right back from the dead
		owner.death()
	owner = null

/obj/item/organ/proc/set_owner(mob/living/carbon/human/H, datum/species/S)
	loc = null
	owner = H

/obj/item/organ/proc/die()
	if(is_robotic())
		return
	damage = max_damage
	status |= ORGAN_DEAD
	STOP_PROCESSING(SSobj, src)
	if(owner && vital)
		owner.death()

/obj/item/organ/process()

	//dead already, no need for more processing
	if(status & ORGAN_DEAD)
		return

	if(is_preserved())
		return

	//Process infections
	if ((is_robotic()) || (sterile) ||(owner && owner.species && (owner.species.flags & IS_PLANT)))
		germ_level = 0
		return

	if(!owner)
		if(reagents)
			var/datum/reagent/blood/B = locate(/datum/reagent/blood) in reagents.reagent_list
			if(B && prob(40))
				reagents.remove_reagent("blood",0.1)
				blood_splatter(src,B,1)
		// Maybe scale it down a bit, have it REALLY kick in once past the basic infection threshold
		// Another mercy for surgeons preparing transplant organs
		germ_level++
		if(germ_level >= INFECTION_LEVEL_ONE)
			germ_level += rand(2,6)
		if(germ_level >= INFECTION_LEVEL_TWO)
			germ_level += rand(2,6)
		if(germ_level >= INFECTION_LEVEL_THREE)
			die()

		if(damage >= max_damage)
			die()

	else if(owner.bodytemperature >= 170)	//cryo stops germs from moving and doing their bad stuffs
		//** Handle antibiotics and curing infections
		handle_antibiotics()

	//check if we've hit max_damage
	if(damage >= max_damage)
		die()

/obj/item/organ/proc/insert_organ(mob/living/carbon/human/H, surgically = FALSE, datum/species/S)
	set_owner(H, S)

	STOP_PROCESSING(SSobj, src)

	if(parent_bodypart)
		parent = owner.bodyparts_by_name[parent_bodypart]

/obj/item/organ/proc/replaced(mob/living/carbon/human/target, obj/item/organ/external/parent_bodypart)

	if(!istype(target)) return

	owner = target
	STOP_PROCESSING(SSobj, src)
	parent_bodypart.bodypart_organs |= src
	if (!target.get_int_organ(src))
		target.organs_by_name += src
		target.organs += src
	src.loc = target
	if(is_robotic())
		status |= ORGAN_ROBOT

/obj/item/organ/proc/receive_chem(chemical)
	return 0

/obj/item/organ/proc/get_icon(icon/race_icon, icon/deform_icon)
	return icon('icons/mob/human.dmi',"blank")

//Germs
/obj/item/organ/proc/handle_antibiotics()
	var/antibiotics = owner.reagents.get_reagent_amount("spaceacillin")

	if (!germ_level || antibiotics < 5)
		return

	if (germ_level < INFECTION_LEVEL_ONE)
		germ_level = 0	//cure instantly
	else if (germ_level < INFECTION_LEVEL_TWO)
		germ_level -= 6	//at germ_level == 500, this should cure the infection in a minute
	else
		germ_level -= 2 //at germ_level == 1000, this will cure the infection in 5 minutes

/obj/item/organ/proc/is_preserved()
	if(istype(loc,/obj/item/organ))
		var/obj/item/organ/O = loc
		return O.is_preserved()
	else
		return (istype(loc,/obj/structure/closet/secure_closet/freezer) || istype(loc,/obj/structure/closet/crate/freezer))

/obj/item/organ/take_damage(amount, silent=0)
	if(!isnum(silent))
		return // prevent basic take_damage usage (TODO remove workaround)
	if(is_robotic())
		src.damage += (amount * 0.8)
	else
		src.damage += amount

		//only show this if the organ is not robotic
		if(owner && parent_bodypart && amount > 0)
			var/obj/item/organ/external/parent = owner.get_organ(parent_bodypart)
			if(parent && !silent)
				owner.custom_pain("Something inside your [parent.name] hurts a lot.", 1)

/obj/item/organ/examine(mob/user)
	. = ..(user)
	show_decay_status(user)

/obj/item/organ/proc/show_decay_status(mob/user)
	if(status & ORGAN_DEAD)
		to_chat(user, "<span class='notice'>The decay has set into \the [src].</span>")

//Handles chem traces
/mob/living/carbon/human/proc/handle_trace_chems()
	//New are added for reagents to random bodyparts.
	for(var/datum/reagent/A in reagents.reagent_list)
		var/obj/item/organ/external/BP = pick(bodyparts)
		BP.trace_chemicals[A.name] = 100

//Adds autopsy data for used_weapon. Use type damage: brute, burn, mixed, bruise (weak punch, e.g. fist punch)
/obj/item/organ/proc/add_autopsy_data(used_weapon, damage, type_damage)
	var/weapon_name

	if(isatom(used_weapon))
		var/atom/weapon = used_weapon
		weapon_name = initial(weapon.name)
	else
		weapon_name = used_weapon

	var/datum/autopsy_data/W = autopsy_data[weapon_name + worldtime2text()]

	if(!W)
		W = new()
		W.weapon = weapon_name
		autopsy_data[weapon_name + worldtime2text()] = W

	var/time = W.time_inflicted
	if(time != worldtime2text())
		W = new()
		W.weapon = weapon_name
		autopsy_data[weapon_name + worldtime2text()] = W

	W.hits += 1
	W.damage += damage
	W.time_inflicted = worldtime2text()
	W.type_damage = type_damage

// Takes care of bodypart and their organs related updates, such as broken and missing limbs
/mob/living/carbon/human/proc/handle_bodyparts()
	number_wounds = 0
	var/force_process = 0
	var/damage_this_tick = getBruteLoss() + getFireLoss() + getToxLoss()
	if(damage_this_tick > last_dam)
		force_process = 1
	last_dam = damage_this_tick
	if(force_process)
		bad_bodyparts.Cut()
		for(var/obj/item/organ/external/BP in bodyparts)
			bad_bodyparts += BP

	//processing organs is pretty cheap, do that first.
	for(var/obj/item/organ/internal/IO in organs)
		IO.process()
		IO.on_life()

	handle_stance()

	if(!force_process && !bad_bodyparts.len)
		return

	for(var/obj/item/organ/external/BP in bad_bodyparts)
		if(!BP || QDELETED(BP))
			bad_bodyparts -= BP
			continue
		if(!BP.need_process())
			bad_bodyparts -= BP
			continue
		else
			BP.process()
			number_wounds += BP.number_wounds

			if (!lying && world.time - l_move_time < 15)
			//Moving around with fractured ribs won't do you any good
				if (BP.is_broken() && BP.bodypart_organs.len && prob(15))
					var/obj/item/organ/internal/IO = pick(BP.bodypart_organs)
					custom_pain("You feel broken bones moving in your [BP.name]!", 1)
					IO.take_damage(rand(3, 5))

				//Moving makes open wounds get infected much faster
				if (BP.wounds.len)
					for(var/datum/wound/W in BP.wounds)
						if (W.infection_check())
							W.germ_level += 1


/obj/item/organ/proc/is_robotic()
	if(status & ORGAN_ROBOT)
		return TRUE
	return FALSE

/obj/item/organ/proc/mechanize() //Being used to make robutt hearts, etc
	status &= ~ORGAN_BROKEN
	status &= ~ORGAN_SPLINTED
	status += ORGAN_ROBOT


/mob/living/carbon/human/proc/handle_stance()
	// Don't need to process any of this if they aren't standing anyways
	// unless their stance is damaged, and we want to check if they should stay down
	if(!stance_damage && lying && (life_tick % 4) != 0)
		return

	stance_damage = 0

	// Buckled to a bed/chair. Stance damage is forced to 0 since they're sitting on something solid
	if(istype(buckled, /obj/structure/stool))
		return

	for(var/limb_tag in list(BP_L_LEG, BP_R_LEG))
		var/obj/item/organ/external/E = bodyparts_by_name[limb_tag]
		if(!E?.is_usable())
			stance_damage += 2 // let it fail even if just foot&leg
		else if(E.is_malfunctioning())
			//malfunctioning only happens intermittently so treat it as a missing limb when it procs
			stance_damage += 2
			if(prob(10))
				visible_message("\The [src]'s [E.name] [pick("twitches", "shudders")] and sparks!")
				var/datum/effect/effect/system/spark_spread/spark_system = new ()
				spark_system.set_up(5, 0, src)
				spark_system.attach(src)
				spark_system.start()
		else if(E.is_broken())
			stance_damage += 1

	// Canes and crutches help you stand (if the latter is ever added)
	// One cane mitigates a broken leg+foot, or a missing foot.
	// Two canes are needed for a lost leg. If you are missing both legs, canes aren't gonna help you.
	if (l_hand && istype(l_hand, /obj/item/weapon/cane))
		stance_damage -= 2
	if (r_hand && istype(r_hand, /obj/item/weapon/cane))
		stance_damage -= 2

	// standing is good
	if(stance_damage < 2 || (stance_damage < 4 && prob(95)))
		return

	if(!lying)
		if(species && !species.flags[NO_PAIN])
			emote("scream")
		Weaken(2)

	if(iszombie(src)) // workaroud for zombie attack without stance
		if(!crawling)
			if(crawl_can_use())
				crawl()
			else
				Stun(5)
				Weaken(5)
				return
	else
		Weaken(5) //can't emote while weakened, apparently.

	if(lying)
		var/has_arm = FALSE
		for(var/limb_tag in list(BP_L_ARM, BP_R_ARM))
			var/obj/item/organ/external/E = bodyparts_by_name[limb_tag]
			if(E?.is_usable())
				has_arm = TRUE
				break
		if(!has_arm) //need atleast one hand to crawl
			Stun(5)

/obj/item/organ/proc/is_primary_organ(mob/living/carbon/human/O = null)
	if (isnull(O))
		O = owner
	if (!istype(owner)) // You're not the primary organ of ANYTHING, bucko
		return 0
	return src == O.get_int_organ(organ_tag)
