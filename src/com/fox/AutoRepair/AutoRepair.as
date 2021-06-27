import com.GameInterface.DistributedValue;
import com.GameInterface.Game.Character;
import com.GameInterface.Game.CharacterBase;
import com.GameInterface.DialogIF;
import com.Utils.Archive;
import com.Utils.LDBFormat;
import mx.utils.Delegate;

class com.fox.AutoRepair.AutoRepair{
	private var m_Character:Character;
	private var AutoBuyPotions:DistributedValue;
	private var AutoLeap:DistributedValue;
	private var AutoChest:DistributedValue;
	private var LootBox:DistributedValue;
	private var timeout;
	private var buffer;

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
	}
	
	public function Load(){
		m_Character = Character.GetClientCharacter();
		//revive
		m_Character.SignalCharacterAlive.Connect(Revived, this);
		m_Character.SignalCharacterTeleported.Connect(Revived, this);
		//potions
		m_Character.SignalStatChanged.Connect(SlotStatChanged, this);
		//teleport
		DialogIF.SignalShowDialog.Connect(AcceptTeleportBuffer, this);
		//lootbox
		DialogIF.SignalShowDialog.Connect(AcceptKeyBuffer, this);
		CharacterBase.SignalClientCharacterOfferedLootBox.Connect(OfferedLootbox, this);
		CharacterBase.SignalClientCharacterOpenedLootBox.Connect(OpenedBox, this);
	}
	
	public function Unload(){
		//revive
		m_Character.SignalCharacterAlive.Disconnect(Revived, this);
		m_Character.SignalCharacterTeleported.Disconnect(Revived, this);
		//potions
		m_Character.SignalStatChanged.Disconnect(SlotStatChanged, this);
		//teleport
		DialogIF.SignalShowDialog.Disconnect(AcceptTeleportBuffer, this);
		//lootbox
		DialogIF.SignalShowDialog.Disconnect(AcceptKeyBuffer, this);
		CharacterBase.SignalClientCharacterOfferedLootBox.Disconnect(OfferedLootbox, this);
		CharacterBase.SignalClientCharacterOpenedLootBox.Disconnect(OpenedBox, this);
	}
	
	public function Activate(config:Archive){
		AutoBuyPotions.SetValue(config.FindEntry("autobuy", false));
		AutoLeap.SetValue(config.FindEntry("autoleap", false));
		AutoChest.SetValue(config.FindEntry("Autochest", false));
	}
	
	public function Deactivate():Archive{
		var arch:Archive = new Archive();
		arch.AddEntry("autobuy", AutoBuyPotions.GetValue());
		arch.AddEntry("autoleap", AutoLeap.GetValue());
		arch.AddEntry("Autochest", AutoChest.GetValue());
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
	
	private function OfferedLootbox(items:Array, tokenTypes:Array, boxType:Array, backgroundID:Number){
		if (AutoChest.GetValue()){
			
			// Patron Chests
			for (var i:Number = 0; i < tokenTypes.length; i++){
				// Dungeon
				if (tokenTypes[i] == _global.Enums.Token.e_Dungeon_Key) {				
					if ( m_Character.GetTokens(_global.Enums.Token.e_Dungeon_Key) > 0){
						OpenBox(tokenTypes[i]);
						return;
					}
					else {
						LootBox.SetValue(false);
					}
				}
				// Lair 
				if (tokenTypes[i] == _global.Enums.Token.e_Lair_Key) {
					if (m_Character.GetTokens(_global.Enums.Token.e_Lair_Key) > 0){
						OpenBox(tokenTypes[i]);
						return;
					}
					else {
						LootBox.SetValue(false);
					}
				}
				// Scenario
				if (tokenTypes[i] == _global.Enums.Token.e_Scenario_Key) {
					if (m_Character.GetTokens(_global.Enums.Token.e_Scenario_Key) > 0){
						OpenBox(tokenTypes[i]);
						return;
					}
					else {
						LootBox.SetValue(false);
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
	
	private function Setbought(){
		timeout = undefined;
	}

	// Some delay for KeyConfirm mod
	private function AcceptKeyBuffer(dialog){
		if (AutoChest.GetValue()){
			clearTimeout(buffer);
			buffer = setTimeout(Delegate.create(this, AcceptKey), 25, dialog);
		}
	}
	// 56146837 Dungeon
	// 32891557 lair
	// 226452453 Scenario
	private function AcceptKey(dialog){
		// Already bought
		if (timeout){
			return;
		}
		var safetyCheck = LDBFormat.LDBGetText(100, 56146837).split("%")[0];
		if (dialog["m_Message"].toString().indexOf(safetyCheck) == 0){
			timeout = setTimeout(Delegate.create(this, Setbought), 1000);
			dialog.DisconnectAllSignals();
			dialog.Respond(0);
			dialog.Close();
		}
		safetyCheck = LDBFormat.LDBGetText(100, 32891557).split("%")[0];
		if (dialog["m_Message"].toString().indexOf(safetyCheck) == 0){
			timeout = setTimeout(Delegate.create(this, Setbought), 1000);
			dialog.DisconnectAllSignals();
			dialog.Respond(0)
			dialog.Close();
		}
		safetyCheck = LDBFormat.LDBGetText(100, 226452453).split("%")[0];
		if (dialog["m_Message"].toString().indexOf(safetyCheck) == 0){
			timeout = setTimeout(Delegate.create(this, Setbought), 1000);
			dialog.DisconnectAllSignals();
			dialog.Respond(0)
			dialog.Close();
		}
	}
}