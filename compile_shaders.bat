@echo off
call :treeProcess
goto :eof

:perShader

rem Call oish_gen.exe on every shader that is found
rem Will generate an .oiSH file from it

rem echo Found a shader named %~1 with %~2 stages and id %~3
set /a end=%~2-1
set "args="%~dp0oish_gen.exe" "%~4" "%~1" !stages[0]!"
for /l %%x in (1, 1, %end%) do set args=!args! !stages[%%x]!
cmd /c "%args%"

rem Remove all the .spv and .ospv files generated for this shader
rem Since those are intermediate files

for /l %%y in (0, 1, %end%) do (
 del /F /Q "%~4!stages[%%y]!.ospv"
 del /F /Q "%~4!stages[%%y]!.spv"
)

exit /b

:treeProcess

setlocal enabledelayedexpansion

set /a i=0
set /a j=-1

for %%f in (*.vert *.frag *.comp *.geom) do (

	rem Compile shader source into spir-v code
	"%VULKAN_SDK%/Bin/glslangValidator.exe" -V -e main "%%~ff" -o "%%~nf%%~xf.spv"
	
	rem Optimize shader source code and strip all reflection data from source
	"%VULKAN_SDK%/Bin/spirv-opt.exe" -Os -O "%%~nf%%~xf.spv" -o "%%~nf%%~xf.ospv"
	"%VULKAN_SDK%/Bin/spirv-remap.exe" --do-everything -i "%%~nf%%~xf.ospv" -o ../shaders/
	
	rem Call 'perShader' if the shader name changes
	
	if NOT !name!==%%~nf (
		if defined !name! (
			call :perShader !name! !i! !j! !fullname!
		)
		
		set stages[0]=%%~xf
		set /a i=1
		set /a j=!j!+1
	)
	
	if !name!==%%~nf (
		set stages[!i!]=%%~xf
		set /a i=!i!+1
	)
	
	
	set name=%%~nf
	set fullname=%%~df%%~pf%%~nf
)

if defined name (
	call :perShader %name% %i% %j% %fullname%
)

endlocal

rem go through other directories inside this directory
for /D %%d in (*) do (
    cd %%d
    call :treeProcess
    cd ..
)