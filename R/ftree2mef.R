## ftree2mef
# Copyright 2017 OpenReliability.org
#
# Conversion of FaultTree data to Model Exchange Format in XML
# to enable input to packages conforming to the open-PRA initiative
# with specific interest in SCRAM http://scram-pra.org/
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
##

ftree2mef<-function(DF, DFname="", dir="", write_file=FALSE, system_mission_time=NULL)  {
  if(!FaultTree::test.ftree(DF)) stop("first argument must be a fault tree")

if (is.null(system_mission_time)) {
	if(exists("mission_time")) {
		system_mission_time<-"mission_time"
## This reads the environment variable 'misssion_time' as MT
		MT <- eval((parse(text = system_mission_time)))
	}else{
		if(any(DF$Type==5)) {
## warning("mission_time not avaliable, SCRAM default assumed")
		MT<-8760
		}
	}
# It is only possible to confirm mission_time here, not reset it
}else{
warning("any value for system_mission_time given here is ignored, SCRAM default 8760 assumed")
}


## test that there are no empty gates, all tree leaves must be basic component events
## Identify gates and events by ID
	gids<-DF$ID[which(DF$Type>9)]
	pids<-DF$CParent
	if(length(setdiff(gids, pids))>0) {
	stop(paste0("no children at gate(s) ID= ", setdiff(gids, pids)))
	}

  if(any(DF$Type==13) || any(DF$Type==14) || any(DF$Type==15)) {
  stop("ALARM, PRIORITY, and VOTE gates are not implemented for SCRAM calls")
  }
  if(any(DF$Type==1) || any(DF$Type==2)|| any(DF$Type==3)) {
  stop("Repairable model types: Active, Latent, and Demand not implemented for SCRAM calls")
  }
##  issue warning if default tags must be issued.
	if(any(DF$Tag_Obj[which(DF$Type<6)]=="")) {
	warning("Not all basic-events have tags, defaults applied")
	}

##  DF might be the DF object within the scram.cutsets environment
## in that event the DFname must be provided
 hold_name<-paste(deparse(substitute(DF)))
  if(DFname=="") {
## test and fail if hold_name=="DF" while no DFname provided
    if(hold_name=="DF"){
      stop("must provide DFname as an argument in any do.call function as done in scram.cutsets")
    }else{
        DFname<-hold_name
    }
  }

lb<-"\n"

## eids<-DF$ID[which(DF$Type<10)]
types<-NULL
for(gate in 1:length(gids)) {
  if (DF$Type[which(DF$ID==gids[gate])]==10) {
    types <- c(types, "or")
  } else if (DF$Type[which(DF$ID==gids[gate])]==16) {
    types <- c(types, "atleast");
  } else if (DF$Type[which(DF$ID==gids[gate])]==17) {
    types <- c(types, "passthrough");
  } else {
    types <- c(types, "and");
  }
}


	treeXML=""
	for(gate in 1:length(gids)) {
	  # Name this element
	  tagname<-DF$Tag_Obj[which(DF$ID==gids[gate])]
		if(tagname=="") {
			tagname<-paste0("G_", gids[gate])
		}

		treeXML<-paste0(treeXML,'<define-gate name="',tagname, '">',lb)

		if (DF$Type[which(DF$ID==gids[gate])]==16) {
			p1<-DF$P1[which(DF$ID==gids[gate])]
			treeXML<-paste0(treeXML,'<',types[gate],' min="',p1,'">',lb)
		} else {
		  if (DF$Type[which(DF$ID==gids[gate])]!=17) {
		    # no <and>, <or>, etc. for a passthrough (NULL) gate
	      treeXML<-paste0(treeXML,'<',types[gate],'>',lb)
		  }
		}

## Define the children of this gate applying default tag names where needed
		chids<-DF$ID[which(DF$CParent==gids[gate])]

		for(child in 1:length(chids)) {
			tagname<-DF$Tag_Obj[which(DF$ID==chids[child])]
			if(DF$Type[which(DF$ID==chids[child])]>9) {
				if(tagname=="")  {
					tagname<-paste0("G_", chids[child])
				}
				treeXML<-paste0(treeXML,'<gate name="',tagname,'"/>',lb)
			}else{
# Like gates, house events should not come with tags
				if(DF$Type[which(DF$ID==chids[child])]==6) {
					if(tagname=="")  {
						tagname<-paste0("H_", chids[child])
					}
					treeXML<-paste0(treeXML,'<house-event name="',tagname,'"/>',lb)
				}else{
					if(tagname=="")  {
## must use source ID for MOE when assigning default tagname to events
						if(DF$MOE[which(DF$ID==chids[child])]<1)  {
							tagname<-paste0("E_", chids[child])
						}else{
							tagname<-paste0("E_", DF$MOE[which(DF$ID==chids[child])])
						}
					}
					treeXML<-paste0(treeXML,'<basic-event name="',tagname,'"/>',lb)
				} ## added else block closure due to house tag code
			}
		}
		if (DF$Type[which(DF$ID==gids[gate])]!=17) {
		  treeXML<-paste0(treeXML, ' </',types[gate],'>',lb)
		}
		treeXML<-paste0(treeXML,'</define-gate>',lb)
	}

	treeXML<-paste0(treeXML,'</define-fault-tree>',lb)

	modelXML<-paste0('<model-data>',lb)

## start of eventXML generation
	eids<-DF$ID[which(DF$Type<6)]
	eventXML<-""
	for(event in 1:length(eids)) {
## cannot replicate MOE tags in mef, else get redifine basic-event error from scram
		if(DF$MOE[which(DF$ID==eids[event])]<1)  {
			tagname<-DF$Tag_Obj[which(DF$ID==eids[event])]
			if(tagname=="")  {
				tagname<-paste0("E_", eids[event])
			}

			eventXML<-paste0(eventXML, '<define-basic-event name="', tagname, '">',lb)

## This is the location to determine which distribution and deviate should be applied
## Any exposed event from FaultTree, could be handled as a fixed probability with deviate applied.
etype<-DF$EType[which(DF$ID==eids[event])]
utype<-DF$UType[which(DF$ID==eids[event])]
dev_param<-floor(utype/10)
deviate<-utype-10*dev_param

## using thie flag saves nesting else clauses
event_entry_done=FALSE

## This is the code for basic-event having fixed probability entry with deviate, if applicable
## Original assumption was that DF$EType[which(DF$ID==eids[event])==0
# if(DF$EType[which(DF$ID==eids[event])==0)  {
## this test will handle fixed probability cases or any exposed element that is defined to deviate on='prob'
## alternatively, if(etype==0 || (utype>0&&utype<10) would have worked for deviate on='prob'
if(etype==0 || (deviate>0&&dev_param==0))  {
## required to stop further handling of exposed element with deviate on 'prob'
event_entry_done=TRUE
			# if(DF$UType[which(DF$ID==eids[event])]>0) {
			if(deviate>0) {
				# if(DF$UType[which(DF$ID==eids[event])]==1) {
				if(deviate==1) {
					eventXML<-paste0(eventXML, '<uniform-deviate>',lb)
## uniform-deviate ignores any mean probability entry
					if(DF$UP1[which(DF$ID==eids[event])]>0) {
						eventXML<-paste0(eventXML, '<float value="',DF$UP1[which(DF$ID==eids[event])], '"/>',lb)
					}else{
						stop(paste0("uncertainty parameter expected at DF$UP1[",which(DF$ID==eids[event]),"]"))
					}
					if(DF$UP2[which(DF$ID==eids[event])]>0) {
						eventXML<-paste0(eventXML, '<float value="',DF$UP2[which(DF$ID==eids[event])], '"/>',lb)
					}else{
						stop(paste0("uncertainty parameter expected at DF$UP2[",which(DF$ID==eids[event]),"]"))
					}
					eventXML<-paste0(eventXML, '</uniform-deviate>',lb)
				}

				# if(DF$UType[which(DF$ID==eids[event])]==2) {
				if(deviate==2) {
					eventXML<-paste0(eventXML, '<normal-deviate>',lb)
					if(DF$PBF[which(DF$ID==eids[event])]>0) {
						eventXML=paste0(eventXML, '<float value="', DF$PBF[which(DF$ID==eids[event])], '"/>',lb)
					}else{
						stop(paste0("must have probability at DF$PBF[",which(DF$ID==eids[event]),"]"))
					}
					if(DF$UP1[which(DF$ID==eids[event])]>0) {
						eventXML<-paste0(eventXML, '<float value="',DF$UP1[which(DF$ID==eids[event])], '"/>',lb)
					}else{
						stop(paste0("uncertainty parameter expected at DF$UP1[",which(DF$ID==eids[event]),"]"))
					}
					eventXML<-paste0(eventXML, '</normal-deviate>',lb)
				}

				# if(DF$UType[which(DF$ID==eids[event])]==3) {
				if(deviate==3) {
				eventXML<-paste0(eventXML, '<lognormal-deviate>',lb)
				if(DF$PBF[which(DF$ID==eids[event])]>0) {
					eventXML=paste0(eventXML, '<float value="', DF$PBF[which(DF$ID==eids[event])], '"/>',lb)
					}else{
						stop(paste0("must have probability at DF$PBF[",which(DF$ID==eids[event]),"]"))
					}
					if(DF$UP1[which(DF$ID==eids[event])]>0) {
						eventXML<-paste0(eventXML, '<float value="',DF$UP1[which(DF$ID==eids[event])], '"/>',lb)
					}else{
						stop(paste0("uncertainty parameter expected at DF$UP1[",which(DF$ID==eids[event]),"]"))
					}
					if(DF$UP2[which(DF$ID==eids[event])]>0) {
						eventXML<-paste0(eventXML, '<float value="',DF$UP2[which(DF$ID==eids[event])], '"/>',lb)
					}else{
						stop(paste0("uncertainty parameter expected at DF$UP2[",which(DF$ID==eids[event]),"]"))
					}
				eventXML<-paste0(eventXML, '</lognormal-deviate>',lb)
				}


				# if(DF$UType[which(DF$ID==eids[event])]>3) {
				if(deviate>3) {
					stop(paste0("uncertainty deviate type ",DF$UType[which(DF$ID==eids[event])]," has not been defined" ))
				}
			}else{
				if(DF$PBF[which(DF$ID==eids[event])]>0) {
					eventXML=paste0(eventXML, '<float value="', DF$PBF[which(DF$ID==eids[event])], '"/>',lb)
					}else{
						stop(paste0("must have probability at DF$PBF[",which(DF$ID==eids[event]),"]"))
					}

			}
			eventXML<-paste0(eventXML, '</define-basic-event>',lb)
}
## end of fixed probability basic-event and any applicable deviate entry

## This is the code for exponential basic-event entry with lambda deviate, if applicable
# if(DF$EType[which(DF$ID==eids[event])]==1)  {
if(event_entry_done==FALSE && etype==1)  {
## not sure this is required, but should't hurt
event_entry_done=TRUE
eventXML<-paste0(eventXML, '<exponential>',lb)
			# if(DF$UType[which(DF$ID==eids[event])]>0) {
			if(utype>0) {
## original tests here would have failed, because exponential utypes on lambda should be  11, 12, or 13
## the deviate determination above handles this now
				# if(DF$UType[which(DF$ID==eids[event])]==1) {
				if(deviate==1) {
					eventXML<-paste0(eventXML, '<uniform-deviate>',lb)
## uniform-deviate requires lower and upper values for CFR to be in UP1 and UP2
					if(DF$UP1[which(DF$ID==eids[event])]>0) {
						eventXML<-paste0(eventXML, '<float value="',DF$UP1[which(DF$ID==eids[event])], '"/>',lb)
					}else{
						stop(paste0("uncertainty parameter expected at DF$UP1[",which(DF$ID==eids[event]),"]"))
					}
					if(DF$UP2[which(DF$ID==eids[event])]>0) {
						eventXML<-paste0(eventXML, '<float value="',DF$UP2[which(DF$ID==eids[event])], '"/>',lb)
					}else{
						stop(paste0("uncertainty parameter expected at DF$UP2[",which(DF$ID==eids[event]),"]"))
					}
					eventXML<-paste0(eventXML, '</uniform-deviate>',lb)
				}

				# if(DF$UType[which(DF$ID==eids[event])]==2) {
				if(deviate==2) {
					eventXML<-paste0(eventXML, '<normal-deviate>',lb)
					if(DF$CFR[which(DF$ID==eids[event])]>0) {
						eventXML=paste0(eventXML, '<float value="', DF$CFR[which(DF$ID==eids[event])], '"/>',lb)
					}else{
						stop(paste0("must have fail rate at DF$CFR[",which(DF$ID==eids[event]),"]"))
					}
					if(DF$UP1[which(DF$ID==eids[event])]>0) {
						eventXML<-paste0(eventXML, '<float value="',DF$UP1[which(DF$ID==eids[event])], '"/>',lb)
					}else{
						stop(paste0("uncertainty parameter expected at DF$UP1[",which(DF$ID==eids[event]),"]"))
					}
					eventXML<-paste0(eventXML, '</normal-deviate>',lb)
				}

				# if(DF$UType[which(DF$ID==eids[event])]==3) {
				if(deviate==3) {
				eventXML<-paste0(eventXML, '<lognormal-deviate>',lb)
				if(DF$CFR[which(DF$ID==eids[event])]>0) {
					eventXML=paste0(eventXML, '<float value="', DF$CFR[which(DF$ID==eids[event])], '"/>',lb)
					}else{
						stop(paste0("must have fail rate at DF$CFR[",which(DF$ID==eids[event]),"]"))
					}
					if(DF$UP1[which(DF$ID==eids[event])]>0) {
						eventXML<-paste0(eventXML, '<float value="',DF$UP1[which(DF$ID==eids[event])], '"/>',lb)
					}else{
						stop(paste0("uncertainty parameter expected at DF$UP1[",which(DF$ID==eids[event]),"]"))
					}
					if(DF$UP2[which(DF$ID==eids[event])]>0) {
						eventXML<-paste0(eventXML, '<float value="',DF$UP2[which(DF$ID==eids[event])], '"/>',lb)
					}else{
						stop(paste0("uncertainty parameter expected at DF$UP2[",which(DF$ID==eids[event]),"]"))
					}
				eventXML<-paste0(eventXML, '</lognormal-deviate>',lb)
				}


				# if(DF$UType[which(DF$ID==eids[event])]>3) {
				if(deviate>3) {
				#	stop(paste0("uncertainty deviate type ",DF$UType[which(DF$ID==eids[event])]," has not been defined" ))
					stop(paste0("uncertainty deviate type ",deviate," has not been defined" ))
				}
			}else{
				if(DF$CFR[which(DF$ID==eids[event])]>0) {
					eventXML=paste0(eventXML, '<float value="', DF$CFR[which(DF$ID==eids[event])], '"/>',lb)
					}else{
						stop(paste0("must have fail rate at DF$CFR[",which(DF$ID==eids[event]),"]"))
					}

			}

if(DF$P2[which(DF$ID==eids[event])]==MT)  {
	eventXML<-paste0(eventXML, '<system-mission-time/>',lb)
}else{
	eventXML<-paste0(eventXML, '<float value="', DF$P2[which(DF$ID==eids[event])] , '"/>',lb)
}

				eventXML<-paste0(eventXML, '</exponential>',lb)
eventXML<-paste0(eventXML, '</define-basic-event>',lb)
}
## end of exponential basic-event and applicable deviate on 'lambda'

		}
	}

## end of eventXML generation

## start of houseXML generation
	hids<-DF$ID[which(DF$Type==6)]
	houseXML<-""
	if(length(hids>0))  {
		for(hevent in 1:length(hids))  {
			tagname<-DF$Tag_Obj[which(DF$ID==hids[hevent])]
			if(tagname=="")  {
				tagname<-paste0("H_", hids[hevent])
			}
			houseXML<-paste0(houseXML, '<define-house-event name="', tagname, '">',lb)
			hval="true"
			if(DF$PBF[which(DF$ID==hids[hevent])]==0)  { hval="false" }
			houseXML<-paste0(houseXML, '<constant value="', hval, '"/>',lb)
			houseXML<-paste0(houseXML, '</define-house-event>',lb)
		}
	}
	
## start of undevelopedXML generation
	uids<-DF$ID[which(DF$Type==7)]
	undevelopedXML<-""
	if(length(uids>0))  {
	  for(uevent in 1:length(uids))  {
	    tagname<-DF$Tag_Obj[which(DF$ID==uids[uevent])]
	    if(tagname=="")  {
	      tagname<-paste0("U_", hids[uevent])
	    }
	    undevelopedXML<-paste0(undevelopedXML, '<define-basic-event name="', tagname, '">',lb)
	    undevelopedXML<-paste0(undevelopedXML, '<attributes> <attribute name="flavor" value="undeveloped"/> </attributes>',lb)
	    undevelopedXML<-paste0(undevelopedXML, '<float value="', DF$PBF[which(DF$ID==uids[uevent])] , '"/>',lb)
	    undevelopedXML<-paste0(undevelopedXML, '</define-basic-event>',lb)
	  }
	}


	XMLhead<-paste0('<!DOCTYPE opsa-mef>',lb,
	'<opsa-mef>',lb,
	'<define-fault-tree name="',
	DFname, '">',lb)


	XMLfoot<-paste0('</model-data>',lb,'</opsa-mef>',lb)


	outstring<-paste0(XMLhead, treeXML, modelXML, eventXML, houseXML, undevelopedXML, XMLfoot)

	if(write_file==TRUE)  {
		file_name<-paste0(dir,DFname,"_mef.xml")
		eval(parse(text=paste0('write(outstring,"',file_name,'")')))
	}

	outstring
}