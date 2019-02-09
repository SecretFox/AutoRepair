import com.GameInterface.DistributedValue;
import com.GameInterface.Game.BuffData;
import com.GameInterface.Game.Character;
import com.GameInterface.Game.CharacterBase;
import com.GameInterface.DialogIF;
import com.Utils.Archive;
import com.Utils.LDBFormat;
import mx.utils.Delegate;

class com.fox.AutoRepair.AutoRepair{	
	private var m_Character:Character;
	private var AutoBuyPotions:DistributedValue;
	private var DEATH_PENALTY_BUFF:Number = 9285457;
	
	public static function main(swfRoot:MovieClip):Void{
		var mod = new AutoRepair(swfRoot)
		swfRoot.onLoad  = function() { mod.Load(); };
		swfRoot.onUnload  = function() { mod.Unload();};
		swfRoot.OnModuleActivated = function(config:Archive) {mod.Activate(config)};
		swfRoot.OnModuleDeactivated = function() {return mod.Deactivate()};
	}
	
    public function AutoRepair(swfRoot: MovieClip){
		AutoBuyPotions = DistributedValue.Create("AutoBuyPotions");
	}
	
	public function Load(){
		m_Character = new Character(CharacterBase.GetClientCharID());
		m_Character.SignalCharacterTeleported.Connect(Revived, this);
		m_Character.SignalStatChanged.Connect(SlotStatChanged, this);
	}
	
	public function Unload(){
		m_Character.SignalCharacterTeleported.Disconnect(Revived, this);
		m_Character.SignalStatChanged.Disconnect(SlotStatChanged, this);
	}
	
	public function Activate(config:Archive){
		AutoBuyPotions.SetValue(config.FindEntry("autobuy", false));
	}
	
	public function Deactivate():Archive{
		var arch:Archive = new Archive();
		arch.AddEntry("autobuy", AutoBuyPotions.GetValue());
		return arch
	}
	
	private function SlotStatChanged(stat:Number){
		if (stat == _global.Enums.Stat.e_PotionCount){
			if(AutoBuyPotions.GetValue()){
				var currentCount:Number = m_Character.GetStat(_global.Enums.Stat.e_PotionCount);
				if (!currentCount){
					DialogIF.SignalShowDialog.Connect(AcceptBuy, this);
					Character.BuyPotionRefill();
					DialogIF.SignalShowDialog.Disconnect(AcceptBuy, this);
				}
			}
		}
	}
	
	private function Revived(){
		var buff:BuffData = m_Character.m_InvisibleBuffList[DEATH_PENALTY_BUFF];
		if (buff){
			DialogIF.SignalShowDialog.Connect(AcceptRepair, this);
			CharacterBase.ClearDeathPenalty();
			DialogIF.SignalShowDialog.Disconnect(AcceptRepair, this);
		}
	}
	
	private function AcceptBuy(dialogue){
		var safetycheck = dialogue["m_Message"].toString().slice(0, 24);
		if (LDBFormat.LDBGetText(100, 235500533).indexOf(safetycheck) == 0){
			dialogue.Respond(0);
			dialogue.Close();
		}
	}
	
	private function AcceptRepair(dialogue){
		var safetycheck = dialogue["m_Message"].toString().slice(0, 17);
		if (LDBFormat.LDBGetText(100, 184719378).indexOf(safetycheck) == 0){
			dialogue.Respond(0);
			dialogue.Close();
		}
	}
}