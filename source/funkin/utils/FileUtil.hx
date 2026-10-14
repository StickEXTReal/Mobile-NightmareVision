package funkin.utils;

import haxe.io.Bytes as HaxeBytes;

import lime.ui.FileDialog;
import lime.utils.Bytes;

import openfl.utils.ByteArray;
import openfl.net.FileFilter;
import openfl.filesystem.File;

typedef BrowseOptions =
{
	var ?typeFilter:Array<FileFilter>;
	var ?title:String;
	var ?defaultSearch:String;
}

/**
 * Utility class to make browsing and saving files a little bit more convenient
 */
@:nullSafety
class FileUtil
{
	#if android
	private static var _saveFile_jni = JNI.createStaticMethod("mobile/backend/java/FileUtils", "saveFile", "(Ljava/lang/String;Ljava/lang/String;)V");
	private static var _browseForFile = JNI.createStaticMethod("mobile/backend/java/FileUtils", "browseFiles", "(Ljava/lang/String;Lorg/haxe/lime/HaxeObject;)V");
	private static var _browseForMultipleFiles = JNI.createStaticMethod("mobile/backend/java/FileUtils", "browseForMultipleFiles", "(Ljava/lang/String;Lorg/haxe/lime/HaxeObject;)V");
	private static var _onSelectCallback:Null<String->Void> = null;
	private static var _onCancelCallback:Null<Void->Void> = null; // fuck you IOS
	#end
	
	/**
	 * Triggers a system native file selection dialog.
	 * 
	 * This function acts as a cross-platform bridge:
	 * - On Android: It opens the system's file picker via JNI (FileUtils.java), 
	 *   supporting specific MimeType filters and returning the file via a callback object.
	 * - On Desktop: It invokes the native OS file dialog (Windows/Mac/Linux).
	 * 
	 * @param options Configuration for the dialog (title, filters, etc.).
	 * @param onSelect Callback executed when the user selects a file.
	 * @param onCancel Callback executed when the user closes the dialog without selection.
	 */
	public static function browseForFile(options:BrowseOptions, ?onSelect:String->Void, ?onCancel:Void->Void)
	{
		final title = options.title;
		final filters = options.typeFilter;
		final startPath = options.defaultSearch;
		
		#if android
		_onSelectCallback = onSelect;
		_onCancelCallback = onCancel;
		
		var mimeType:String = "*/*";
		if (options.typeFilter != null && options.typeFilter.length > 0)
		{
			var ext = options.typeFilter[0].extension;
			if (ext == "json") mimeType = "application/json";
			else if (ext == "txt") mimeType = "text/plain";
		}
		
		var callback =
			{
				onFileSelected: function(bytes:haxe.io.BytesData, fileName:String):Void {
					var cb = _onSelectCallback;
					if (cb != null)
					{
						cb(fileName);
					}
				},
				onCancel: function():Void {
					var cb = _onCancelCallback;
					if (cb != null) cb();
				}
			};
		_browseForFile(mimeType, callback);
		#elseif desktop
		FileDialog.openFile(FlxG.stage.window, title, (files, filter) -> {
			if (files != null && files.length > 0)
			{
				if (onSelect != null) onSelect(files[0]);
			}
			else
			{
				if (onCancel != null) onCancel();
			}
		}, @:privateAccess @:nullSafety(Off) File.__getFilterTypes(filters), startPath);
		#end
	}
	
    /**
     * Opens a system native dialog to select multiple files simultaneously.
     * 
     * Function behavior per platform:
     * - On Android: Triggers the Storage Access Framework (ACTION_OPEN_DOCUMENT) via JNI 
     *   with multi-selection enabled. Selected files are temporarily copied to an accessible 
     *   directory and their paths are passed to the callback.
     * - On Desktop: Invokes the OS-specific file picker dialog allowing multiple file selection. 
     *   Upon confirmation, it returns the absolute paths of the chosen files.
     * 
     * @param options Configuration for the dialog, including title, file type filters, and starting path.
     * @param onSelect Callback triggered when files are successfully selected, receiving an array of file paths.
     * @param onCancel Callback triggered if the user cancels or closes the dialog without selecting anything.
     */
	public static function browseForMultipleFiles(options:BrowseOptions, ?onSelect:Array<String>->Void, ?onCancel:Void->Void)
	{
		#if android
		try
		{
			var mimeType:String = "application/json";
			
			var callback =
				{
					onFileSelected: function(bytes:Dynamic, fileList:Dynamic) {
						if (onSelect != null)
						{
							if (Std.isOfType(fileList, Array))
							{
								onSelect(fileList);
							}
							else
							{
								onSelect([Std.string(fileList)]);
							}
						}
					},
					onCancel: function() {
						if (onCancel != null) onCancel();
					}
				};
			_browseForMultipleFiles(mimeType, callback);
		}
		#elseif desktop
		final title = options.title;
		final filters = options.typeFilter;
		final startPath = options.defaultSearch;
		FileDialog.openFile(FlxG.stage.window, title, (files, filter) -> {
			if (files != null && files.length > 0)
			{
				if (onSelect != null) onSelect(files);
			}
			else
			{
				if (onCancel != null) onCancel();
			}
		}, @:privateAccess @:nullSafety(Off) File.__getFilterTypes(filters), startPath, true);
		#end
	}
	
	/**
	 * Opens a system native dialog to save a file to a specific location.
	 * 
	 * Function behavior per platform:
	 * - On Android: Triggers the Storage Access Framework (ACTION_CREATE_DOCUMENT) via JNI. 
	 *   It converts the provided data to a string and lets the user choose the destination.
	 * - On Desktop: Invokes the OS-specific save dialog. Upon selection, it writes the 
	 *   bytes directly to the chosen path.
	 * 
	 * @param data The content to be saved (can be Bytes, String, or Dynamic).
	 * @param fileName Default name for the file in the dialog.
	 * @param onSelect Callback triggered when the dialog opens (Android) or file is saved (Desktop).
	 * @param onCancel Callback triggered if the user cancels the operation.
	 */
	public static function saveFile(data:Dynamic, ?fileName:String, ?onSelect:String->Void, ?onCancel:Void->Void)
	{
		if (data == null) return;
		
		#if android
		try
		{
			var content:String = "";
			
			if (data is HaxeBytes)
			{
				content = (cast data : HaxeBytes).toString();
			}
			else if (Std.isOfType(data, String))
			{
				content = data;
			}
			else
			{
				content = Std.string(data);
			}
			
			_saveFile_jni(fileName != null ? fileName : "file.json", content);
			
			if (onSelect != null) onSelect("Storage Picker Opened");
		}
		catch (e:Dynamic)
		{
			Logger.log('[FileUtil.saveFile] JNI Error: $e', ERROR);
			if (onCancel != null) onCancel();
		}
		#elseif desktop
		var filters = null;
		if (fileName != null && fileName.extension().length > 0)
		{
			final ext:String = fileName.extension();
			filters = [new lime.ui.FileDialogFilter('*.$ext', ext)];
		}
		
		FileDialog.saveFile(FlxG.stage.window, 'Save', (file, filter) -> {
			if (file != null && file.length > 0)
			{
				Bytes.toFile(file, dynamicToBytes(data));
				
				if (onSelect != null) onSelect(file);
			}
			else
			{
				if (onCancel != null) onCancel();
			}
		}, filters, fileName);
		#end
	}
	
	public static function saveFileToPath(data:Dynamic, path:String, ensureDirectory:Bool = true):Bool
	{
		try
		{
			if (ensureDirectory && path.directory() != '' && !FunkinAssets.isDirectory(#if mobile StorageSystem.getDirectory() + #end path.directory()))
			{
				FileSystem.createDirectory(#if mobile StorageSystem.getDirectory() + #end path.directory());
			}
			
			Bytes.toFile(#if mobile StorageSystem.getDirectory() + #end path, dynamicToBytes(data));
			return true;
		}
		catch (e)
		{
			Logger.log('Failed to save to $path\nException: $e', ERROR);
			return false;
		}
	}
	
	static function dynamicToBytes(input:Dynamic):Bytes
	{
		if (input is ByteArrayData || input is HaxeBytes) return input;
		
		final bytes = new ByteArray();
		bytes.writeUTFBytes(Std.string(input));
		
		return bytes;
	}
}
