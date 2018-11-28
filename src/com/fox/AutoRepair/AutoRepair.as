import com.GameInterface.Game.Character;
import com.GameInterface.Game.CharacterBase;
import com.GameInterface.DialogIF;
import com.GameInterface.PlayerDeath;
import com.Utils.LDBFormat;
import mx.utils.Delegate;

class com.fox.AutoRepair.AutoRepair{	
	private var player:Character;
	
	public static function main(swfRoot:MovieClip):Void{
		var instance = new AutoRepair(swfRoot)
		swfRoot.onLoad  = function() { instance.Init();};
		swfRoot.OnModuleActivated = function() {instance.RegisterSignal()}
		swfRoot.OnModuleDeactivated = function() {instance.RemoveSignal()}
	}
	
    public function AutoRepair(swfRoot: MovieClip){}
		
	private function Revived(){
		DialogIF.SignalShowDialog.Connect(Accept, this);
		CharacterBase.ClearDeathPenalty();
		DialogIF.SignalShowDialog.Disconnect(Accept, this);
	}
	
	private function Accept(dialogue){
		var safety = dialogue["m_Message"].toString().slice(0, 10);
		var check:String = LDBFormat.LDBGetText(100, 184719378)
		if (check.indexOf(safety) != -1){
			dialogue.Respond(0);
		}
		dialogue.Close();
	}
	
	public function Init(){
		player = new Character(CharacterBase.GetClientCharID());
	}
	
	public function RegisterSignal(){
		player.SignalCharacterTeleported.Connect(Revived, this);
	}
	
	public function RemoveSignal(){
		player.SignalCharacterTeleported.Disconnect(Revived, this);
		DialogIF.SignalShowDialog.Disconnect(Accept, this);
	}
	
}