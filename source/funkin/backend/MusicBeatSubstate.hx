package funkin.backend;

import flixel.FlxSubState;
import flixel.util.FlxDestroyUtil;
import flixel.group.FlxGroup.FlxTypedGroup;

import funkin.input.Controls;
import funkin.data.*;
import funkin.scripts.*;

#if mobile
import flixel.group.FlxGroup;
import mobile.controls.MobileHitbox;
import mobile.controls.MobileVirtualPad;
#end

class MusicBeatSubstate extends FlxSubState
{
    public static var instance:MusicBeatSubstate;
    
	public function new()
	{
	    instance = this;
		super();
	}
	
	private var curSection:Int = 0;
	private var stepsToDo:Int = 0;
	
	private var lastBeat:Float = 0;
	private var lastStep:Float = 0;
	
	private var curStep:Int = 0;
	private var curBeat:Int = 0;
	
	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	private var controls(get, never):Controls;
	
	inline function get_controls():Controls return Controls.instance;
	
	#if mobile
	public var virtualPad:MobileVirtualPad;
	public var virtualPadCam:FlxCamera;
	
	public var hitbox:MobileHitbox;
	public var hitboxCam:FlxCamera;

    public function addVirtualPad(DPad:String, Action:String)
	{
		virtualPad = new MobileVirtualPad(DPad, Action);
		add(virtualPad);
	}
	
	public function addMobileControls(DefaultDrawTarget:Bool = false)
	{
		hitbox = new MobileHitbox();

		hitboxCam = new FlxCamera();
		hitboxCam.bgColor.alpha = 0;
		FlxG.cameras.add(hitboxCam, DefaultDrawTarget);

		hitbox.cameras = [hitboxCam];
		hitbox.visible = false;
		add(hitbox);
	}
	
	public function addVirtualPadCamera(DefaultDrawTarget:Bool = false)
	{
		if (virtualPad != null)
		{
			virtualPadCam = new FlxCamera();
			virtualPadCam.bgColor.alpha = 0;
			FlxG.cameras.add(virtualPadCam, DefaultDrawTarget);
			
			virtualPad.cameras = [virtualPadCam];
		}
	}

	public function removeVirtualPad()
	{
		if (virtualPad != null)
		{
			remove(virtualPad);
			virtualPad = FlxDestroyUtil.destroy(virtualPad);
		}

		if(virtualPadCam != null)
		{
			FlxG.cameras.remove(virtualPadCam);
			virtualPadCam = FlxDestroyUtil.destroy(virtualPadCam);
		}
	}
	
	public function removeMobileControls()
	{
		if (hitbox != null)
		{
			remove(hitbox);
			hitbox = FlxDestroyUtil.destroy(hitbox);
		}

		if(hitboxCam != null)
		{
			FlxG.cameras.remove(hitboxCam);
			hitboxCam = FlxDestroyUtil.destroy(hitboxCam);
		}
	}
	#end
	
	public var scripted:Bool = false;
	public var scriptName:String = '';
	public var scriptPrefix:String = 'substates';
	public var scriptGroup:ScriptGroup = new ScriptGroup();
	
	public function initStateScript(?scriptName:String, callOnLoad:Bool = true):Bool
	{
		if (scriptName == null)
		{
			final stateName = Type.getClassName(Type.getClass(this)).split('.').pop();
			scriptName = stateName ?? '???';
		}
		
		this.scriptName = scriptName;
		
		final scriptFile = FunkinScript.getPath('scripts/$scriptPrefix/$scriptName');
		
		if (FunkinAssets.exists(scriptFile))
		{
			var _script = FunkinScript.fromFile(scriptFile);
			if (_script.parsingFailed())
			{
				_script = FlxDestroyUtil.destroy(_script);
				return false;
			}
			
			scriptGroup.parent = this;
			
			Logger.log('script [$scriptName] initialized', NOTICE);
			
			scriptGroup.addScript(_script);
			scripted = true;
		}
		
		if (callOnLoad) scriptGroup.call('onLoad', []);
		
		return scripted;
	}
	
	public function refreshZ(?group:FlxTypedGroup<FlxBasic>)
	{
		group ??= FlxG.state;
		group.sort(SortUtil.sortByZ, flixel.util.FlxSort.ASCENDING);
	}
	
	override function update(elapsed:Float)
	{
		var oldStep:Int = curStep;
		
		updateCurStep();
		updateBeat();
		
		if (oldStep != curStep)
		{
			if (curStep > 0) stepHit();
			
			if (PlayState.SONG != null)
			{
				if (oldStep < curStep) updateSection();
				else rollbackSection();
			}
		}
		
		scriptGroup.call('onUpdate', [elapsed]);
		
		super.update(elapsed);
	}
	
	private function updateSection():Void
	{
		if (stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
		while (curStep >= stepsToDo)
		{
			curSection++;
			var beats:Float = getBeatsOnSection();
			stepsToDo += Math.round(beats * 4);
			sectionHit();
		}
	}
	
	private function rollbackSection():Void
	{
		if (curStep < 0) return;
		
		var lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] != null)
			{
				stepsToDo += Math.round(getBeatsOnSection() * 4);
				if (stepsToDo > curStep) break;
				
				curSection++;
			}
		}
		
		if (curSection > lastSection) sectionHit();
	}
	
	function getBeatsOnSection():Float
	{
		return PlayState.SONG?.notes[curSection]?.sectionBeats ?? 4.0;
	}
	
	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep / 4;
	}
	
	private function updateCurStep():Void
	{
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);
		
		var shit = ((Conductor.songPosition - ClientPrefs.noteOffset) - lastChange.songTime) / lastChange.stepCrotchet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}
	
	public function stepHit():Void
	{
		if (curStep % 4 == 0) beatHit();
		scriptGroup.call('onStepHit', [curStep]);
	}
	
	public function beatHit():Void
	{
		scriptGroup.call('onBeatHit', [curBeat]);
	}
	
	public function sectionHit()
	{
		scriptGroup.call('onSectionHit');
	}
	
	override function destroy()
	{
		scriptGroup.call('onDestroy', []);
		
		scriptGroup = FlxDestroyUtil.destroy(scriptGroup);
		
		super.destroy();
		
		#if mobile
		removeVirtualPad();
		removeMobileControls();
		#end
	}
}
