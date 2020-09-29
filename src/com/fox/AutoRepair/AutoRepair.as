import com.GameInterface.AccountManagement;
import com.GameInterface.DistributedValue;
import com.GameInterface.Game.Character;
import com.GameInterface.Game.CharacterBase;
import com.GameInterface.DialogIF;
import com.GameInterface.Inventory;
import com.Utils.Archive;
import com.Utils.LDBFormat;
import mx.utils.Delegate;

class com.fox.AutoRepair.AutoRepair{
	private var m_Character:Character;
	private var m_Inventory:Inventory;
	private var AutoBuyPotions:DistributedValue;
	private var AutoLeap:DistributedValue;
	private var timeout;
	private var buffer;
	private var boughtToken:Number;

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
	}
	
	public function Unload(){
		//revive
		m_Character.SignalCharacterAlive.Disconnect(Revived, this);
		m_Character.SignalCharacterTeleported.Disconnect(Revived, this);
		//potions
		m_Character.SignalStatChanged.Disconnect(SlotStatChanged, this);
		//teleport
		DialogIF.SignalShowDialog.Disconnect(AcceptTeleportBuffer, this);
	}
	
	public function Activate(config:Archive){
		AutoBuyPotions.SetValue(config.FindEntry("autobuy", false));
		AutoLeap.SetValue(config.FindEntry("autoleap", false));
	}
	
	public function Deactivate():Archive{
		var arch:Archive = new Archive();
		arch.AddEntry("autobuy", AutoBuyPotions.GetValue());
		arch.AddEntry("autoleap", AutoLeap.GetValue());
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
}