package animate;

import flixel.FlxG;
import haxe.io.Bytes;
import openfl.display.BitmapData;

using StringTools;

/**
 * Wrapper for assets to allow HaxeFlixel 5.9.0+ and HaxeFlixel 5.8.0- compatibility.
 * Class to be used for replacing the method used for loading assets, if using ``FlxAnimateFrames.fromAnimate`` through a folder path.
 * For more control over loading texture atlases I recommend using the rest of the params in the ``fromAnimate`` frame loader.
 */
class FlxAnimateAssets
{
	public static dynamic function exists(path:String, type:AssetType):Bool
	{
		// Check openfl/flixel assets first
		#if (flixel >= "5.9.0")
		if (FlxG.assets.exists(path, type))
			return true;
		#else
		if (Assets.exists(path, type))
			return true;
		#end

		// Fallback to filesystem
		#if sys
		return FileSystem.exists(path);
		#end

		return false;
	}

	public static dynamic function getText(path:String):String
	{
		// Check openfl/flixel assets first
		#if (flixel >= "5.9.0")
		if (FlxG.assets.exists(path, AssetType.TEXT))
			return FlxG.assets.getText(path);
		#else
		if (Assets.exists(path, AssetType.TEXT))
			return Assets.getText(path);
		#end

		// Fallback to filesystem
		#if sys
		if (FileSystem.exists(path))
			return File.getContent(path);
		#end

		return null;
	}

	public static dynamic function getBytes(path:String):Bytes
	{
		// Check openfl/flixel assets first
		#if (flixel >= "5.9.0")
		if (FlxG.assets.exists(path, AssetType.BINARY))
			return FlxG.assets.getBytes(path);
		#else
		if (Assets.exists(path, AssetType.BINARY))
			return Assets.getBytes(path);
		#end

		// Fallback to filesystem
		#if sys
		if (FileSystem.exists(path))
			return File.getBytes(path);
		#end

		return null;
	}

	public static dynamic function getBitmapData(path:String):BitmapData
	{
		// Check openfl/flixel assets first
		#if (flixel >= "5.9.0")
		if (FlxG.assets.exists(path, AssetType.IMAGE))
			return FlxG.assets.getBitmapData(path);
		#else
		if (Assets.exists(path, AssetType.IMAGE))
			return Assets.getBitmapData(path);
		#end

		// Fallback to filesystem
		#if sys
		if (FileSystem.exists(path))
			return BitmapData.fromFile(path);
		#end

		return null;
	}

	public static dynamic function list(path:String, ?type:AssetType, ?library:String, includeSubDirectories:Bool = false):Array<String>
	{
		var result:Array<String> = null;

		// Check openfl/flixel assets first
		result = #if (flixel >= "5.9.0") FlxG.assets.list(type); #else openfl.utils.Assets.list(type); #end

		if (result == null)
			result = [];

		// Fallback to filesystem for non-library assets
		#if sys
		if (library == null || library.length == 0)
		{
			if (FileSystem.exists(path))
			{
				var files:Array<String> = FileSystem.readDirectory(path);
				var result:Array<String> = [];
				var checkSubDirectory:String->Void = null;

				checkSubDirectory = (file) ->
				{
					if (FileSystem.isDirectory('$path/$file') && includeSubDirectories)
					{
						var files = FileSystem.readDirectory('$path/$file').map((subFile) -> '$file/$subFile');
						for (file in files)
							checkSubDirectory(file);
					}
					else
					{
						result.push(file);
					}
				};

				for (file in files)
					checkSubDirectory(file);

				return result;
			}
		}
		#end

		// Get only the files actually contained inside the Texture Atlas folder
		// Plus some formatting to be easier to use afterwards
		return result.filter((str) -> str.startsWith(path.substring(path.indexOf(':') + 1, path.length)))
			.map((str) -> str.split('${path.split(":").pop()}/').pop());
	}
}

typedef AssetType = #if (flixel >= "5.9.0") flixel.system.frontEnds.AssetFrontEnd.FlxAssetType #else openfl.utils.AssetType #end;
