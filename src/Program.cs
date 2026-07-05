// AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core)
// SPDX-License-Identifier: AGPL-3.0-or-later
// This program bundles ONLYOFFICE components (x2t, sdkjs), Copyright (C) Ascensio System SIA,
// also under AGPLv3. See --license, LICENSE, and THIRD-PARTY-NOTICES.md.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Xml;

class Program
{
    // Bundle versions injected at build time from /VERSIONS (single source of truth),
    // see the ReadBundleVersions target in Abx2t.csproj.
    static readonly string OnlyOfficeVersion   = GetAssemblyMetadata("OnlyOfficeVersion");
    static readonly string OnlyOfficeCoreBuild = GetAssemblyMetadata("OnlyOfficeCoreBuild");

    static string GetAssemblyMetadata(string key)
    {
        foreach (var attr in Assembly.GetExecutingAssembly()
                     .GetCustomAttributes(typeof(AssemblyMetadataAttribute), false))
            if (attr is AssemblyMetadataAttribute meta && meta.Key == key && !string.IsNullOrEmpty(meta.Value))
                return meta.Value;
        return "unknown";
    }

    static string LicenseNotice => $@"AbX2T - Copyright (C) 2026 Hugo Lagouardat (Abend-core project)
https://github.com/Abend-core/AbX2T

This program is free software: you can redistribute it and/or modify it under the terms of
the GNU Affero General Public License, version 3, as published by the Free Software
Foundation. This program is distributed WITHOUT ANY WARRANTY. Full license text:
https://www.gnu.org/licenses/agpl-3.0.html (LICENSE file in this repository).

Bundled third-party components:
  ONLYOFFICE x2t / sdkjs (conversion engine and runtime), version {OnlyOfficeCoreBuild}
  Copyright (C) Ascensio System SIA - https://www.onlyoffice.com
  License: GNU AGPLv3. Corresponding source (exact version):
    https://github.com/ONLYOFFICE/core/releases/tag/v{OnlyOfficeCoreBuild}
    https://github.com/ONLYOFFICE/sdkjs/releases/tag/v{OnlyOfficeCoreBuild}
  Unmodified components, simply packaged and invoked as a subprocess by AbX2T.
  These binaries embed further third-party libraries (ICU, FreeType, HarfBuzz, V8, ...);
  see 3DPARTY.md in the ONLYOFFICE/core repository.

  allfontsgen (font indexer built from ONLYOFFICE/core sources, AGPLv3).
  Portions of this software are copyright (C) The FreeType Project
  (https://www.freetype.org). All rights reserved.

AbX2T is not affiliated with, endorsed by, or sponsored by Ascensio System SIA / ONLYOFFICE.
Full details: THIRD-PARTY-NOTICES.md and LICENSE, extracted to resources/ on first run and
available in the source repository.";

    // Formats read by ONLYOFFICE in this bundle (word/cell/slide/visio/pdf + x2t/bin DLLs, see
    // docs/SUPPORTED_FORMATS.md). Written formats: subset actually writable
    // (legacy binary and e-book/scan formats are read but never written back by ONLYOFFICE).
    static readonly string[] InputExtensions = {
        "doc","docx","docm","dotx","dotm","odt","ott","rtf","txt","html","mht","epub","fb2","mobi","hwp","hwpx","md",
        "ppt","pptx","pptm","ppsx","ppsm","potx","potm","odp","otp",
        "xls","xlsx","xlsm","xltx","xltm","xlsb","ods","ots","csv",
        "pdf","djvu","xps","ofd",
        "vsdx","vssx","vstx","vsdm","vssm","vstm",
    };

    static readonly string[] OutputExtensions = {
        "docx","odt","rtf","txt","html","pdf",
        "pptx","odp",
        "xlsx","ods","csv",
        "xps",
    };

    static int Main(string[] args)
    {
        if (args.Length >= 1 && (args[0] == "--license" || args[0] == "--licence" || args[0] == "--about"))
        {
            Console.WriteLine(LicenseNotice);
            return 0;
        }

        if (args.Length < 2)
        {
            string progName = Path.GetFileName(Environment.ProcessPath) ?? "Abx2t";
            Console.Error.WriteLine($"Usage: {progName} <source> <output>");
            Console.Error.WriteLine($"  Accepted input  : .{string.Join(", .", InputExtensions)}");
            Console.Error.WriteLine($"  Accepted output : .{string.Join(", .", OutputExtensions)}");
            Console.Error.WriteLine($"  {progName} --license : AGPLv3 license and ONLYOFFICE attribution");
            return 1;
        }

        string input  = Path.GetFullPath(args[0]);
        string output = Path.GetFullPath(args[1]);

        if (!File.Exists(input))
        {
            Console.Error.WriteLine($"Error: source file not found: {input}");
            return 1;
        }

        string inputExt = Path.GetExtension(input).ToLowerInvariant().TrimStart('.');
        if (Array.IndexOf(InputExtensions, inputExt) < 0)
        {
            Console.Error.WriteLine($"Error: unsupported input format (.{inputExt}). " +
                                     $"Accepted formats: .{string.Join(", .", InputExtensions)}");
            return 1;
        }

        string outputExt = Path.GetExtension(output).ToLowerInvariant().TrimStart('.');
        if (Array.IndexOf(OutputExtensions, outputExt) < 0)
        {
            Console.Error.WriteLine($"Error: unsupported output format (.{outputExt}). " +
                                     $"Accepted formats: .{string.Join(", .", OutputExtensions)}");
            return 1;
        }

        string exeDir         = AppContext.BaseDirectory;
        string resourcesDir   = Path.Combine(exeDir, "resources");
        string allfontsDir    = Path.Combine(exeDir, "allfonts");
        string customFontsDir = Path.Combine(exeDir, "custom-fonts");
        string x2tPath        = Path.Combine(resourcesDir, OperatingSystem.IsWindows() ? "x2t.exe" : "x2t");
        string allFonts       = Path.Combine(allfontsDir, "AllFonts.js");
        string fontsManifest  = Path.Combine(allfontsDir, "fonts.manifest");

        // Extract assets when missing, stale or incomplete. resources/.version is written
        // LAST, after a successful extraction: it is both the bundle version marker (an
        // Abx2t update ships a new assets.zip -> version differs -> re-extract) and the
        // completeness marker (a crash mid-extraction leaves no marker -> re-extract).
        string versionMarker    = Path.Combine(resourcesDir, ".version");
        string installedVersion = File.Exists(versionMarker) ? File.ReadAllText(versionMarker).Trim() : "";
        if (!File.Exists(x2tPath) || installedVersion != OnlyOfficeCoreBuild)
        {
            Console.WriteLine(installedVersion.Length == 0
                ? "First run: extracting components..."
                : $"Bundle update ({installedVersion} -> {OnlyOfficeCoreBuild}): re-extracting components...");
            if (Directory.Exists(resourcesDir))
                Directory.Delete(resourcesDir, recursive: true);
            int r = ExtractAssets(resourcesDir);
            if (r != 0) return r;
            File.WriteAllText(versionMarker, OnlyOfficeCoreBuild);
            // The wipe removed resources/sdkjs/common/AllFonts.js (restored by the font
            // generation): force it to run again.
            if (File.Exists(fontsManifest)) File.Delete(fontsManifest);
            TryCompressResources(resourcesDir);
            Console.WriteLine("Extraction OK.");
        }

        // custom-fonts/ : extra fonts dropped in manually (no Windows install required),
        // indexed by allfontsgen alongside system fonts. Always created so it stays
        // discoverable, even before any font is added.
        Directory.CreateDirectory(customFontsDir);

        // Self-healing font index: allfonts/fonts.manifest captures the exact custom-fonts/
        // state (path|size|mtime per file, plus the bundle version) and is written LAST,
        // after a successful generation. Any added, removed or modified font changes the
        // state; a crash mid-generation leaves no manifest. Both cases -> regenerate.
        string fontsState = ComputeFontsState(customFontsDir);
        bool fontsUpToDate = File.Exists(allFonts)
            && File.Exists(fontsManifest)
            && File.ReadAllText(fontsManifest) == fontsState;
        if (!fontsUpToDate)
        {
            Console.WriteLine("Generating system fonts index...");
            if (File.Exists(fontsManifest)) File.Delete(fontsManifest);
            int r = GenerateFonts(resourcesDir, allfontsDir, allFonts, customFontsDir);
            if (r != 0) return r;
            File.WriteAllText(fontsManifest, fontsState);
            Console.WriteLine("Fonts OK.");
        }

        string sdkjsDir = Path.Combine(resourcesDir, "sdkjs");
        string? outputDir = Path.GetDirectoryName(output);
        if (!string.IsNullOrEmpty(outputDir))
            Directory.CreateDirectory(outputDir);

        // Local work directory (system TEMP): x2t only reads/writes locally, even if the
        // real source or destination is on a network share (\\server\share or a mapped
        // drive). This avoids lock/latency/partial-write issues over the network, and
        // guarantees a crash leaves nothing behind on the share.
        string workDir     = Path.Combine(Path.GetTempPath(), $"x2t_convert_{Guid.NewGuid():N}");
        string tempDir     = Path.Combine(workDir, "temp");
        string localInput  = Path.Combine(workDir, "input." + inputExt);
        string localOutput = Path.Combine(workDir, "output." + outputExt);
        Directory.CreateDirectory(tempDir);
        string configPath = Path.Combine(workDir, "config.xml");
        try
        {
            try
            {
                File.Copy(input, localInput, overwrite: true);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: could not read source file ({input}): {ex.Message}");
                return 1;
            }

            WriteConfig(configPath, localInput, localOutput, allFonts, allfontsDir, sdkjsDir, tempDir);

            var psi = new ProcessStartInfo
            {
                FileName               = x2tPath,
                Arguments              = $"\"{configPath}\"",
                WorkingDirectory       = resourcesDir,
                UseShellExecute        = false,
                RedirectStandardOutput = true,
                RedirectStandardError  = true,
            };

            using var proc = Process.Start(psi)!;
            // Drain both pipes concurrently: reading them one after the other can deadlock
            // if x2t fills the buffer of the pipe not being read.
            var stdoutTask = proc.StandardOutput.ReadToEndAsync();
            var stderrTask = proc.StandardError.ReadToEndAsync();
            proc.WaitForExit();
            string stdout = stdoutTask.Result;
            string stderr = stderrTask.Result;

            if (proc.ExitCode != 0)
            {
                Console.Error.WriteLine($"x2t error (code {proc.ExitCode})");
                if (!string.IsNullOrWhiteSpace(stderr)) Console.Error.WriteLine(stderr);
                if (!string.IsNullOrWhiteSpace(stdout)) Console.Error.WriteLine(stdout);
                return proc.ExitCode;
            }

            if (!File.Exists(localOutput))
            {
                Console.Error.WriteLine("Error: conversion finished but the output file is missing");
                return 1;
            }

            try
            {
                File.Copy(localOutput, output, overwrite: true);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: could not write output file ({output}): {ex.Message}");
                return 1;
            }

            Console.WriteLine($"OK: {output}");
            return 0;
        }
        finally
        {
            if (Directory.Exists(workDir))
                Directory.Delete(workDir, recursive: true);
        }
    }

    static int ExtractAssets(string destDir)
    {
        try
        {
            using Stream? zip = Assembly.GetExecutingAssembly()
                .GetManifestResourceStream("assets.zip");
            if (zip == null)
            {
                Console.Error.WriteLine("Error: assets.zip not found inside the executable");
                return 1;
            }

            // On macOS, x2t/*.framework bundles rely on symlinks (Versions/Current -> A, etc.)
            // and on their code signature's extended attributes. System.IO.Compression.ZipArchive
            // does not restore symlinks on extract (it writes a regular file containing the link
            // target's text instead), which silently breaks the frameworks. ditto is the
            // macOS-native tool that round-trips both correctly, matching how package_macos.sh
            // built this archive.
            if (OperatingSystem.IsMacOS())
                return ExtractAssetsViaDitto(zip, destDir);

            Directory.CreateDirectory(destDir);
            using var archive = new ZipArchive(zip, ZipArchiveMode.Read);
            archive.ExtractToDirectory(destDir, overwriteFiles: true);

            // On Linux, make sure the bundled binaries stay executable even if the archive
            // was built without Unix permissions in its entries (x2t finds its .so libraries
            // next to itself via its RPATH $ORIGIN, so the exec bit is all it needs).
            if (OperatingSystem.IsLinux())
            {
                foreach (string bin in new[] { "x2t", "allfontsgen" })
                {
                    string path = Path.Combine(destDir, bin);
                    if (File.Exists(path))
                        File.SetUnixFileMode(path, File.GetUnixFileMode(path)
                            | UnixFileMode.UserExecute | UnixFileMode.GroupExecute | UnixFileMode.OtherExecute);
                }
            }
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Extraction error: {ex.Message}");
            return 1;
        }
    }

    static int ExtractAssetsViaDitto(Stream zip, string destDir)
    {
        string tempZip = Path.Combine(Path.GetTempPath(), $"assets_{Guid.NewGuid():N}.zip");
        try
        {
            using (var file = File.Create(tempZip))
                zip.CopyTo(file);

            Directory.CreateDirectory(destDir);
            var psi = new ProcessStartInfo
            {
                FileName               = "/usr/bin/ditto",
                UseShellExecute        = false,
                RedirectStandardOutput = true,
                RedirectStandardError  = true,
            };
            psi.ArgumentList.Add("-x");
            psi.ArgumentList.Add("-k");
            psi.ArgumentList.Add(tempZip);
            psi.ArgumentList.Add(destDir);

            using var proc = Process.Start(psi)!;
            string stderr = proc.StandardError.ReadToEnd();
            proc.WaitForExit();
            if (proc.ExitCode != 0)
            {
                Console.Error.WriteLine($"ditto extraction error (code {proc.ExitCode})");
                if (!string.IsNullOrWhiteSpace(stderr)) Console.Error.WriteLine(stderr);
                return proc.ExitCode;
            }
            return 0;
        }
        finally
        {
            File.Delete(tempZip);
        }
    }

    // NTFS transparent compression on resources/ (~160 MB -> ~90-100 MB on disk); x2t reads
    // the files normally. The directory flag is inherited, so files added later (AllFonts.js
    // copied into sdkjs/common) are compressed too. Best-effort: Windows only, and skipped
    // silently on filesystems without compression support (FAT32, exFAT, network shares).
    static void TryCompressResources(string dir)
    {
        if (!OperatingSystem.IsWindows()) return;
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName               = "compact.exe",
                Arguments              = $"/c /s:\"{dir}\" /i /q",
                UseShellExecute        = false,
                RedirectStandardOutput = true,
                RedirectStandardError  = true,
            };
            using var proc = Process.Start(psi);
            if (proc == null) return;
            _ = proc.StandardOutput.ReadToEndAsync();
            _ = proc.StandardError.ReadToEndAsync();
            proc.WaitForExit();
        }
        catch
        {
            // Compression is a disk-footprint optimization, never a failure condition.
        }
    }

    static int GenerateFonts(string resourcesDir, string allfontsDir, string allFontsPath, string customFontsDir)
    {
        string allfontsgenName = OperatingSystem.IsWindows() ? "allfontsgen.exe" : "allfontsgen";
        string allfontsgen = Path.Combine(resourcesDir, allfontsgenName);
        if (!File.Exists(allfontsgen))
        {
            Console.Error.WriteLine($"Error: {allfontsgenName} not found in {resourcesDir}");
            return 1;
        }

        Directory.CreateDirectory(allfontsDir);

        string tmp = Path.Combine(Path.GetTempPath(), $"fonts_{Guid.NewGuid():N}");
        Directory.CreateDirectory(tmp);
        try
        {
            string selectionPath  = Path.Combine(tmp, "font_selection.bin");
            string allFontsTmp    = Path.Combine(tmp, "AllFonts.js");
            string allFontsWebTmp = Path.Combine(tmp, "AllFonts2.js");

            var psi = new ProcessStartInfo
            {
                FileName         = allfontsgen,
                WorkingDirectory = resourcesDir,
                UseShellExecute  = false,
            };
            psi.ArgumentList.Add("--use-system=true");
            psi.ArgumentList.Add("--use-system-user-fonts=true");
            psi.ArgumentList.Add($"--input={customFontsDir}");
            psi.ArgumentList.Add($"--selection={selectionPath}");
            psi.ArgumentList.Add($"--allfonts={allFontsTmp}");
            psi.ArgumentList.Add($"--allfonts-web={allFontsWebTmp}");
            psi.ArgumentList.Add($"--output-web={tmp}");

            using var proc = Process.Start(psi)!;
            proc.WaitForExit();
            if (proc.ExitCode != 0)
            {
                Console.Error.WriteLine($"allfontsgen error (code {proc.ExitCode})");
                return 1;
            }

            File.Copy(allFontsTmp, allFontsPath, overwrite: true);
            File.Copy(selectionPath, Path.Combine(allfontsDir, "font_selection.bin"), overwrite: true);

            string sdkCommon = Path.Combine(resourcesDir, "sdkjs", "common");
            if (Directory.Exists(sdkCommon))
                File.Copy(allFontsTmp, Path.Combine(sdkCommon, "AllFonts.js"), overwrite: true);

            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Font generation error: {ex.Message}");
            return 1;
        }
        finally
        {
            Directory.Delete(tmp, recursive: true);
        }
    }

    // One line per file in custom-fonts/ (relative path|size|mtime ticks), sorted, plus
    // the bundle version: any change to the fonts or a bundle update changes this string,
    // which is compared byte-for-byte against allfonts/fonts.manifest.
    static string ComputeFontsState(string customFontsDir)
    {
        var lines = new List<string>();
        foreach (string f in Directory.EnumerateFiles(customFontsDir, "*", SearchOption.AllDirectories))
            lines.Add($"{Path.GetRelativePath(customFontsDir, f)}|{new FileInfo(f).Length}|{File.GetLastWriteTimeUtc(f).Ticks}");
        lines.Sort(StringComparer.Ordinal);
        return $"bundle={OnlyOfficeCoreBuild}\n{string.Join("\n", lines)}\n";
    }

    static void WriteConfig(string config, string input, string output,
                            string allFonts, string fontDir, string sdkjsDir, string tempDir)
    {
        var settings = new XmlWriterSettings { Indent = true };
        using var w = XmlWriter.Create(config, settings);
        w.WriteStartDocument();
        w.WriteStartElement("TaskQueueDataConvert");
        w.WriteElementString("m_sFileFrom",     input);
        w.WriteElementString("m_sFileTo",       output);
        w.WriteElementString("m_sAllFontsPath", allFonts);
        w.WriteElementString("m_sFontDir",      fontDir);
        w.WriteElementString("m_sThemeDir",     sdkjsDir);
        w.WriteElementString("m_sTempDir",      tempDir);
        w.WriteEndElement();
        w.WriteEndDocument();
    }
}
