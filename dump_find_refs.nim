import osproc, os, strformat, strutils

# TODO This could be provived as an arg
var unityProjectRoot: string = getCurrentDir()

var debug: bool = false

proc debugLog(s: string) =
  if debug: echo s

proc assetPath(): string =
  result = &"{unityProjectRoot}/Assets"

proc outIfErr(output: string, errC: int) =
  if errC != 0:
    echo &"error code: {errC}\n output:{output}"
    quit(0)

proc trimNewLine(s: var string) =
  s.removeSuffix('\n')


proc getUnityGuid(file: string): string =
  let cmd = &"rg --no-ignore guid: {file}.meta"
  debugLog &"get unity guid... cmd is:\n{cmd}"
  var (rgGuidOutput, errc) = execCmdEx(cmd)
  outIfErr(rgGuidOutput,errc)
  var guid = rgGuidOutput.split(' ')[1]
  guid.trimNewLine()
  result = guid


proc getDefinitionFiles(s: string): TaintedString =
  let findFilesCmd = &"global -d {s} {assetPath()}"
  debugLog &"get definition files... cmd is:\n{findFilesCmd}"
  var (files, errC) = execCmdEx(findFilesCmd)
  if files == "" or errC != 0:
    let fallBackCmd = &"rg -l --no-ignore -e \"class\\s+{s}\\s+:\" {assetPath()}"
    (files, errC) = execCmdEx(fallBackCmd)
    # rg no match
    if errC == 1: return ""
  outIfErr(files,errC)
  files.trimNewLine()
  result = files


if not existsDir(assetPath()):
  echo "Enter a unity project root first."
  quit(0)

if paramCount() == 0:
  echo "Please provide the name of the type you want to search for."
  quit(0)

if paramCount() > 1 and paramStr(2) == "-d":
  debug = true

let typeQuery = paramStr(1)
for file in splitLines(getDefinitionFiles(typeQuery)):
  if file != "":
    let guid = getUnityGuid(file)
    # we put the ',' here after the guid enum, because we don't output meta files that way
    let cmd = &"rg -l --no-ignore -e \'guid: {guid},\' {assetPath()}"
    debugLog &"try get guids, cmd: {cmd}"
    let (usages, errC) = execCmdEx(cmd)
    if (errC == 1):
      echo &"Dumb found the guid {guid}, but was unable to find any refs. \"{typeQuery}\""
      quit(0)
    if (errC != 0): debugLog "error while getting guids"
    outIfErr(usages, errC)
    for usagePath in splitLines(usages):
      if usagePath != "":
        echo &"{splitfile(file).name} {relativePath(usagePath,unityProjectRoot)}"
  else: echo &"Dumb find was unable to find definitions for type: \"{typeQuery}\""
