import com.GameInterface.DistributedValue;
import com.GameInterface.Game.BuffData;
import com.GameInterface.Game.Character;
import com.GameInterface.Game.CharacterBase;
import com.GameInterface.DialogIF;
import com.GameInterface.Inventory;
import com.GameInterface.InventoryItem;
import com.Utils.Archive;
import com.Utils.LDBFormat;
import mx.utils.Delegate;
import com.Utils.ID32;

class com.fox.AutoRepair.AutoRepair{
	private var m_Character:Character;
	private var m_Inventory:Inventory;
	private var AutoBuyPotions:DistributedValue;
	private var AutoLeap:DistributedValue;
	private var AutoChest:DistributedValue;
	private var LootBox:DistributedValue;
	private var AutoUseAnima:DistributedValue;
	private var BuffPollingInterval:Number;
	private var timeout;
	
	static var POLLING_INTERVAL_SHORT:Number = 1000; // short polling interval (used when buff not present)
	static var POLLING_INTERVAL_LONG:Number = 10000; // long polling interval (used when buff is present)
	static var PURE_ANIMA_ITEM:Number = 9271323; // Pure Anima - Supreme Potency (item)
	static var PURE_ANIMA_BUFF:Number = 9271325; // Pure Anima - Supreme Potency (buff)
	static var DEATH_BUFFID:Number = 9212298; // dead buff id

	public static function main(swfRoot:MovieClip):Void{
		var mod = new AutoRepair(swfRoot)
		swfRoot.onLoad  = function() { mod.Load(); };
		swfRoot.onUnload  = function() { mod.Unload();};
		swfRoot.OnModuleActivated = function(config:Archive) {mod.Activate(config)};
		swfRoot.OnModuleDeactivated = function() {return mod.Deactivate()};
	}
	
    public function AutoRepair(swfRoot: MovieClip){
		AutoBuyPotions = DistributedValue.Create("AutoBuyPotions");
		AutoLeap = DistributedValue.Create("AutoLeap");
		AutoChest = DistributedValue.Create("AutoOpenChests");
		LootBox = DistributedValue.Create("lootBox_window");
		AutoUseAnima = DistributedValue.Create("AutoUseAnima");
	}
	
	public function Load(){
		m_Character = Character.GetClientCharacter();	
		m_Inventory = new Inventory(new ID32(_global.Enums.InvType.e_Type_GC_BackpackContainer, m_Character.GetID().GetInstance()));
		//revive
		m_Character.SignalCharacterAlive.Connect(Revived, this);
		m_Character.SignalCharacterTeleported.Connect(Revived, this);
		//potions
		m_Character.SignalStatChanged.Connect(SlotStatChanged, this);
		m_Character.SignalToggleCombat.Connect(ToggledCombat, this);
		//teleport
		DialogIF.SignalShowDialog.Connect(AcceptTeleportBuffer, this);
		//lootbox
		CharacterBase.SignalClientCharacterOfferedLootBox.Connect(OfferedLootbox, this);
		CharacterBase.SignalClientCharacterOpenedLootBox.Connect(OpenedBox, this);
	}
	
	public function Unload(){
		//revive
		m_Character.SignalCharacterAlive.Disconnect(Revived, this);
		m_Character.SignalCharacterTeleported.Disconnect(Revived, this);
		//potions
		m_Character.SignalStatChanged.Disconnect(SlotStatChanged, this);
		m_Character.SignalToggleCombat.Disconnect(ToggledCombat, this);
		//teleport
		DialogIF.SignalShowDialog.Disconnect(AcceptTeleportBuffer, this);
		//lootbox
		CharacterBase.SignalClientCharacterOfferedLootBox.Disconnect(OfferedLootbox, this);
		CharacterBase.SignalClientCharacterOpenedLootBox.Disconnect(OpenedBox, this);
	}
	
	public function Activate(config:Archive){
		AutoBuyPotions.SetValue(config.FindEntry("autobuy", false));
		AutoLeap.SetValue(config.FindEntry("autoleap", false));
		AutoChest.SetValue(config.FindEntry("Autochest", false));
		AutoUseAnima.SetValue(config.FindEntry("AutoUseAnima", false));
	}
	
	public function Deactivate():Archive{
		var arch:Archive = new Archive();
		arch.AddEntry("autobuy", AutoBuyPotions.GetValue());
		arch.AddEntry("autoleap", AutoLeap.GetValue());
		arch.AddEntry("Autochest", AutoChest.GetValue());
		arch.AddEntry("AutoUseAnima", AutoUseAnima.GetValue());
		return arch
	}
	
	private function Revived(){
		DialogIF.SignalShowDialog.Connect(AcceptRepair, this);
		CharacterBase.ClearDeathPenalty();
		DialogIF.SignalShowDialog.Disconnect(AcceptRepair, this);
	}
	private function AcceptRepair(dialog){
		var safetycheck = dialog["m_Message"].toString().slice(0, 17);
		if (LDBFormat.LDBGetText(100, 184719378).indexOf(safetycheck) == 0){
			dialog.DisconnectAllSignals();
			dialog.Respond(0)
			dialog.Close();
		}
	}
	//KeyConfirm compatibility
	private function AcceptTeleportBuffer(dialog){
		if (AutoLeap.GetValue()){
			setTimeout(Delegate.create(this, AcceptTeleport), 25, dialog);
		}
	}
	private function AcceptTeleport(dialog){
		var safetycheck = dialog["m_Message"].split("(")[1];
		if (AutoLeap && LDBFormat.LDBGetText(100, 176213916).split("(")[1] == safetycheck){
			dialog.DisconnectAllSignals();
			dialog.Respond(0)
			dialog.Close();
		}
	}
	
	private function SlotStatChanged(stat:Number){
		if (stat == _global.Enums.Stat.e_PotionCount && AutoBuyPotions.GetValue()){
			if (!m_Character.GetStat(_global.Enums.Stat.e_PotionCount)){
				DialogIF.SignalShowDialog.Connect(AcceptPotion, this);
				Character.BuyPotionRefill();
				DialogIF.SignalShowDialog.Disconnect(AcceptPotion, this);
			}
		}
	}
	private function AcceptPotion(dialog){
		// Potion Refill
		if (AutoBuyPotions.GetValue()){
			var safetycheck = dialog["m_Message"].toString().slice(0, 24);
			if (LDBFormat.LDBGetText(100, 235500533).indexOf(safetycheck) == 0){
				dialog.DisconnectAllSignals();
				dialog.Respond(0)
				dialog.Close();
			}
		}
	}

	private function OpenBox(key){
		clearTimeout(timeout);
		timeout = setTimeout(Delegate.create(this, Setbought), 1000); // used to tell box was opened
		CharacterBase.SendLootBoxReply(true, key);
	}
	
	private function OpenedBox(){
		if (AutoChest.GetValue() && timeout){
			LootBox.SetValue(false);
		}
	}
	
	private function Setbought(){
		timeout = undefined;
	}
	
	private function CharacterInNYR() {
		var zone = m_Character.GetPlayfieldID();
		return ( zone == 5710 || zone == 5715); // SM, E1, and E5 are all 5710, E10 & E17 are 5715
	}
	
	private function OfferedLootbox(items:Array, tokenTypes:Array, boxType:Array, backgroundID:Number){
		
		// bail if in NYR and elite key hasn't been used yet
		if ( CharacterInNYR() && ! m_Character.m_InvisibleBuffList[9125207] ) { return;}
		
		if (AutoChest.GetValue()){
			
			// Patron Chests
			for (var i:Number = 0; i < tokenTypes.length; i++){
				// Dungeon
				if (tokenTypes[i] == _global.Enums.Token.e_Dungeon_Key) {				
					if (m_Character.GetTokens(_global.Enums.Token.e_Dungeon_Key) > 0){
						OpenBox(tokenTypes[i]);
						return;
					}
					else {
						com.GameInterface.Chat.SignalShowFIFOMessage.Emit("You are out of dungeon keys.");
						LootBox.SetValue(false);
						return;
					}
				}
				// Lair 
				if (tokenTypes[i] == _global.Enums.Token.e_Lair_Key) {
					if (m_Character.GetTokens(_global.Enums.Token.e_Lair_Key) > 0){
						OpenBox(tokenTypes[i]);
						return;
					}
					else {
						com.GameInterface.Chat.SignalShowFIFOMessage.Emit("You are out of lair keys.");
						LootBox.SetValue(false);
						return;
					}
				}
				// Scenario
				if (tokenTypes[i] == _global.Enums.Token.e_Scenario_Key) {
					if (m_Character.GetTokens(_global.Enums.Token.e_Scenario_Key) > 0){
						OpenBox(tokenTypes[i]);
						return;
					}
					else {
						com.GameInterface.Chat.SignalShowFIFOMessage.Emit("You are out of scenario keys.");
						LootBox.SetValue(false);
						return;
					}
				}
			}
			
			// Free to open chests (lair, dungeon, and scenario), should incldue free chest events
			//										  || Probably this one
			if (!tokenTypes || tokenTypes.length == 0 || tokenTypes == 0){
				OpenBox(0);
			}
		}
	}	
	
	// Auto Anima Code
	
	private function FindAnimaInInventory():Number {		
		for ( var i:Number = 0; i < m_Inventory.GetMaxItems(); i++ ) {
			if ( m_Inventory.GetItemAt(i).m_ACGItem.m_TemplateID0 == PURE_ANIMA_ITEM ) { 
				return i;
			};
		}
		return -1;
	}

	private function UseAnimaPotion() {
		if ( AutoUseAnima.GetValue() ) {
			var slotNo:Number = FindAnimaInInventory();
			if ( slotNo > 0 ) {
				Inventory(m_Inventory).UseItem(slotNo);
				com.GameInterface.UtilsBase.PrintChatText("AutoRepair: Using Pure Anima");
			}
		
			// if we were successful, no need to check for the next 30 minutes, clear the polling interval and reschedule for 30m 01s later
			// This will get reset if we leave combat anyway, so this will only matter if you stay in combat for the next 30 minutes.
			// But at least it will shut off polling for the rest of this combat
			if ( m_Character.m_BuffList[PURE_ANIMA_BUFF] ) {
				RescheduleInterval( 1800001 )
			}
		}
	}
	
	private function RefreshAnimaBuff() {
		// run through some logic to prevent wasting anima potions
		
		// don't use potions out of combat
		// This happens sometimes when sprinting through mobs or in defense cases. ToggleCombat fires even though the player isn't actually in combat.
		if ( ! m_Character.IsInCombat() ) { return;	};
		
		// don't use potions if dead (not sure which of these conditionals is actually needed for death)
		// Actually observed this trigger once when running back in a lair so I suppose we'll keep it
		if ( m_Character.IsDead() || m_Character.m_BuffList[DEATH_BUFFID] || m_Character.m_InvisibleBuffList[DEATH_BUFFID] ) { return; };
		
		// don't use potions if in Agartha (todo: add London, New York, Seoul?)
		if ( m_Character.GetPlayfieldID() == 5060 ) { return; };
		
		// check for sprinting - if "Dismounted" buff not present, don't use
		if ( IsSprinting() ) { return; };

		// check for Equal Footing (events, PVP) - if we see this, clear interval until next combat
		if ( HasEqualFooting() ) { 
			clearInterval(BuffPollingInterval);
			return; 
		};
		
		// check for existing anima buff
		if ( m_Character.m_BuffList[PURE_ANIMA_BUFF] ) {
			// if we already have the buff, reschedule the polling to a longer interval
			RescheduleInterval(POLLING_INTERVAL_LONG);
			return;
		}	
		
		// if we've made it through all of these checks, use an anima
		UseAnimaPotion();
	}
	
	private function RescheduleInterval(intervalAmount:Number) {
		clearInterval(BuffPollingInterval);
		BuffPollingInterval = setInterval(Delegate.create(this, RefreshAnimaBuff), intervalAmount);
	}
	
	private function ToggledCombat(state:Boolean) {
		// only check for refreshes if option is set, we're entering combat, and inventory contains pure anima
		if ( AutoUseAnima.GetValue() && state && ( FindAnimaInInventory() > 0 ) ) {
			// run once on enter combat
			RefreshAnimaBuff();
			// start polling 
			RescheduleInterval(POLLING_INTERVAL_SHORT);	
		}
		else {
			clearInterval(BuffPollingInterval); 
		}
	}
	
	private function IsSprinting():Boolean {
		// this checks the invisible buff list for Sprinting I through VI
		var sprintList;
		sprintList = [ 7481588, 7758936, 7758937, 7758938, 9114480, 9115262];
		
		for ( var item in sprintList ) {
			if m_Character.m_InvisibleBuffList[sprintList[item]] {
				return true;
			}
		}
		return false;
	}
	
	private function HasEqualFooting():Boolean {
		// check for equal footing buffs, efList contains every one in the game just in case
		var efList;
		//         Talos       ?      PVP ------------------------------------------------------------------------------PVP        ?
		efList = [ 7512032, 7512030, 7512342, 7512343, 7512344, 7512345, 7512347, 7512348, 7512349, 7512350, 7512351, 8475143, 9358379];
		
		for ( var item in efList ) {
			if m_Character.m_BuffList[efList[item]] {
				return true;
			}
		}
		return false;
	}
	 
	
	//private function Debug(str:String) {
		//com.GameInterface.UtilsBase.PrintChatText("AR: " + str);
	//}
}