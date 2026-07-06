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
using System.Threading;
using System.Threading.Tasks;
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
    // docs/02-utilisation.md). Written formats: subset actually writable
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

    static string ProgName => Path.GetFileName(Environment.ProcessPath) ?? "Abx2t";

    // Exit codes: 0 = success, 1 = usage or wrapper error, 2 = x2t conversion error,
    // 3 = timeout. Documented in --help so calling scripts can tell them apart.
    static void PrintUsage(TextWriter w)
    {
        w.WriteLine($"Usage: {ProgName} [options] <source> <output>");
        w.WriteLine($"       {ProgName} [options] --to <ext> <sources...> <output_dir>");
        w.WriteLine($"  Accepted input  : .{string.Join(", .", InputExtensions)}");
        w.WriteLine($"  Accepted output : .{string.Join(", .", OutputExtensions)}");
        w.WriteLine();
        w.WriteLine("Options:");
        w.WriteLine("  --to <ext>           Batch mode: output format; each source is converted");
        w.WriteLine("                       into <output_dir> under its own name (wildcards accepted)");
        w.WriteLine("  --jobs <n>           Batch mode: parallel conversions (default: 2-4, from CPU count)");
        w.WriteLine("  --timeout <minutes>  Maximum conversion time per file (default: 30, 0 = no limit)");
        w.WriteLine("  --verbose            Print x2t output even when the conversion succeeds");
        w.WriteLine("  --version            Print the Abx2t / ONLYOFFICE bundle version");
        w.WriteLine("  --license            AGPLv3 license and ONLYOFFICE attribution");
        w.WriteLine("  --help               This help");
        w.WriteLine();
        w.WriteLine("Exit codes: 0 = success, 1 = usage/wrapper error, 2 = x2t error, 3 = timeout");
    }

    static int Main(string[] args)
    {
        var positional = new List<string>();
        bool verbose = false;
        int timeoutMinutes = 30;
        string? toExt = null;
        int jobs = 0;   // 0 = auto (2-4 from CPU count)

        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--license" or "--licence" or "--about":
                    Console.WriteLine(LicenseNotice);
                    return 0;
                case "--version":
                    Console.WriteLine($"{ProgName} {OnlyOfficeCoreBuild} (ONLYOFFICE bundle {OnlyOfficeVersion}, core build {OnlyOfficeCoreBuild})");
                    return 0;
                case "--help" or "-h" or "-?":
                    PrintUsage(Console.Out);
                    return 0;
                case "--verbose" or "-v":
                    verbose = true;
                    break;
                case "--timeout":
                    if (i + 1 >= args.Length || !int.TryParse(args[++i], out timeoutMinutes) || timeoutMinutes < 0)
                    {
                        Console.Error.WriteLine("Error: --timeout expects a number of minutes (0 = no limit)");
                        return 1;
                    }
                    break;
                case "--to":
                    if (i + 1 >= args.Length)
                    {
                        Console.Error.WriteLine("Error: --to expects an output extension (e.g. --to pdf)");
                        return 1;
                    }
                    toExt = args[++i].ToLowerInvariant().TrimStart('.');
                    break;
                case "--jobs":
                    if (i + 1 >= args.Length || !int.TryParse(args[++i], out jobs) || jobs < 1 || jobs > 16)
                    {
                        Console.Error.WriteLine("Error: --jobs expects a number between 1 and 16");
                        return 1;
                    }
                    break;
                default:
                    if (args[i].StartsWith('-'))
                    {
                        Console.Error.WriteLine($"Error: unknown option {args[i]} (see --help)");
                        return 1;
                    }
                    positional.Add(args[i]);
                    break;
            }
        }

        if (positional.Count < 2)
        {
            PrintUsage(Console.Error);
            return 1;
        }

        // Windows shells pass wildcards through unexpanded; expand them ourselves
        // (no-op on Unix, where the shell already did it).
        var sources = ExpandSources(positional.GetRange(0, positional.Count - 1));
        if (sources == null) return 1;
        string outputArg = positional[^1];

        // Batch mode: several sources converted into one target directory. A directory
        // has no extension, so --to provides the output format.
        bool batch = sources.Count > 1 || toExt != null || Directory.Exists(outputArg);

        foreach (string src in sources)
        {
            if (!File.Exists(src))
            {
                Console.Error.WriteLine($"Error: source file not found: {src}");
                return 1;
            }
            string ext = Path.GetExtension(src).ToLowerInvariant().TrimStart('.');
            if (Array.IndexOf(InputExtensions, ext) < 0)
            {
                Console.Error.WriteLine($"Error: unsupported input format (.{ext}) for {src}. " +
                                         $"Accepted formats: .{string.Join(", .", InputExtensions)}");
                return 1;
            }
        }

        var pairs = new List<(string Input, string Output)>();
        if (batch)
        {
            if (toExt == null)
            {
                Console.Error.WriteLine("Error: batch mode (several sources, or a directory as output) requires --to <ext>");
                return 1;
            }
            if (Array.IndexOf(OutputExtensions, toExt) < 0)
            {
                Console.Error.WriteLine($"Error: unsupported output format (.{toExt}). " +
                                         $"Accepted formats: .{string.Join(", .", OutputExtensions)}");
                return 1;
            }
            string outDir = Path.GetFullPath(outputArg);
            Directory.CreateDirectory(outDir);
            // Two sources with the same base name would silently overwrite each other.
            var claimedBy = new Dictionary<string, string>(
                OperatingSystem.IsLinux() ? StringComparer.Ordinal : StringComparer.OrdinalIgnoreCase);
            foreach (string src in sources)
            {
                string dest = Path.Combine(outDir, Path.GetFileNameWithoutExtension(src) + "." + toExt);
                if (claimedBy.TryGetValue(dest, out string? other))
                {
                    Console.Error.WriteLine($"Error: {src} and {other} would both produce {dest}");
                    return 1;
                }
                claimedBy[dest] = src;
                string fullSrc = Path.GetFullPath(src);
                if (PathsEqual(fullSrc, dest))
                {
                    Console.Error.WriteLine($"Error: source and output are the same file: {src}");
                    return 1;
                }
                pairs.Add((fullSrc, dest));
            }
        }
        else
        {
            string input  = Path.GetFullPath(sources[0]);
            string output = Path.GetFullPath(outputArg);
            // Refuse converting a file onto itself: the source would be overwritten by
            // its own reconversion.
            if (PathsEqual(input, output))
            {
                Console.Error.WriteLine("Error: source and output are the same file");
                return 1;
            }
            string outputExt = Path.GetExtension(output).ToLowerInvariant().TrimStart('.');
            if (Array.IndexOf(OutputExtensions, outputExt) < 0)
            {
                Console.Error.WriteLine($"Error: unsupported output format (.{outputExt}). " +
                                         $"Accepted formats: .{string.Join(", .", OutputExtensions)}");
                return 1;
            }
            string? outputDir = Path.GetDirectoryName(output);
            if (!string.IsNullOrEmpty(outputDir))
                Directory.CreateDirectory(outputDir);
            pairs.Add((input, output));
        }

        string baseDir        = ResolveBaseDir(AppContext.BaseDirectory);
        string resourcesDir   = Path.Combine(baseDir, "resources");
        string allfontsDir    = Path.Combine(baseDir, "allfonts");
        string customFontsDir = Path.Combine(baseDir, "custom-fonts");
        string x2tPath        = Path.Combine(resourcesDir, OperatingSystem.IsWindows() ? "x2t.exe" : "x2t");
        string allFonts       = Path.Combine(allfontsDir, "AllFonts.js");
        string fontsManifest  = Path.Combine(allfontsDir, "fonts.manifest");

        // Serialize the preparation of the shared state (resources/, allfonts/): two
        // instances launched simultaneously on a fresh machine would extract and generate
        // over each other. Conversions themselves still run in parallel freely afterwards
        // (each one has its own work dir).
        using (AcquireStateLock(Path.Combine(baseDir, ".abx2t.lock")))
        {
            int r = EnsureComponents(resourcesDir, x2tPath, allfontsDir, allFonts, fontsManifest, customFontsDir);
            if (r != 0) return r;
        }

        string sdkjsDir = Path.Combine(resourcesDir, "sdkjs");

        if (pairs.Count == 1)
            return ConvertOne(x2tPath, resourcesDir, sdkjsDir, allFonts, allfontsDir,
                              pairs[0].Input, pairs[0].Output, timeoutMinutes, verbose, label: "");

        // Batch: a few x2t in parallel (each conversion is independent, own work dir).
        // More than ~4 mostly thrashes disk and memory for no throughput gain.
        if (jobs == 0) jobs = Math.Clamp(Environment.ProcessorCount / 2, 2, 4);
        Console.WriteLine($"Converting {pairs.Count} files to .{toExt} ({jobs} parallel jobs)...");
        var codes = new int[pairs.Count];
        Parallel.For(0, pairs.Count, new ParallelOptions { MaxDegreeOfParallelism = jobs }, i =>
        {
            codes[i] = ConvertOne(x2tPath, resourcesDir, sdkjsDir, allFonts, allfontsDir,
                                  pairs[i].Input, pairs[i].Output, timeoutMinutes, verbose,
                                  label: $"[{Path.GetFileName(pairs[i].Input)}] ");
        });

        int failed = 0, worst = 0;
        foreach (int c in codes)
        {
            if (c != 0) failed++;
            if (c > worst) worst = c;
        }
        Console.WriteLine(failed == 0
            ? $"Done: {pairs.Count}/{pairs.Count} conversions succeeded."
            : $"Done: {pairs.Count - failed}/{pairs.Count} succeeded, {failed} failed.");
        return worst;
    }

    static bool PathsEqual(string a, string b) =>
        string.Equals(a, b, OperatingSystem.IsLinux() ? StringComparison.Ordinal : StringComparison.OrdinalIgnoreCase);

    // Windows shells pass wildcards through unexpanded; expand them here. Returns null
    // (after printing the error) when a pattern matches nothing.
    static List<string>? ExpandSources(List<string> args)
    {
        var result = new List<string>();
        foreach (string a in args)
        {
            if (a.IndexOfAny(new[] { '*', '?' }) < 0)
            {
                result.Add(a);
                continue;
            }
            string dir = Path.GetDirectoryName(a) is { Length: > 0 } d ? d : ".";
            string[] matches;
            try
            {
                matches = Directory.GetFiles(dir, Path.GetFileName(a));
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: cannot expand {a}: {ex.Message}");
                return null;
            }
            if (matches.Length == 0)
            {
                Console.Error.WriteLine($"Error: no file matches {a}");
                return null;
            }
            Array.Sort(matches, StringComparer.Ordinal);
            result.AddRange(matches);
        }
        return result;
    }

    // Serializes multi-line console output in batch mode (single lines interleave fine,
    // each carries its [file] label; error dumps should not).
    static readonly object ConsoleLock = new();

    static int ConvertOne(string x2tPath, string resourcesDir, string sdkjsDir, string allFonts,
                          string allfontsDir, string input, string output,
                          int timeoutMinutes, bool verbose, string label)
    {
        string inputExt  = Path.GetExtension(input).ToLowerInvariant().TrimStart('.');
        string outputExt = Path.GetExtension(output).ToLowerInvariant().TrimStart('.');

        // Work directory in the system TEMP for x2t's config and scratch files. Network
        // source/output paths (\\server\share or a mapped drive) are additionally staged
        // through it, so x2t only ever reads/writes locally: no SMB locks, latency or
        // partial writes on the share, and a crash leaves nothing behind there. Local
        // paths skip the staging copies entirely (no point copying a local file twice).
        string workDir     = Path.Combine(Path.GetTempPath(), $"x2t_convert_{Guid.NewGuid():N}");
        string tempDir     = Path.Combine(workDir, "temp");
        bool stageInput    = IsNetworkPath(input);
        bool stageOutput   = IsNetworkPath(output);
        string localInput  = stageInput  ? Path.Combine(workDir, "input." + inputExt)   : input;
        string localOutput = stageOutput ? Path.Combine(workDir, "output." + outputExt) : output;
        Directory.CreateDirectory(tempDir);
        string configPath = Path.Combine(workDir, "config.xml");
        try
        {
            if (stageInput)
            {
                try
                {
                    File.Copy(input, localInput, overwrite: true);
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"{label}Error: could not read source file ({input}): {ex.Message}");
                    return 1;
                }
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

            Process proc;
            try
            {
                proc = Process.Start(psi)!;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"{label}Error: could not start x2t: {ex.Message}");
                return 1;
            }
            using var _ = proc;
            // Drain both pipes concurrently: reading them one after the other can deadlock
            // if x2t fills the buffer of the pipe not being read.
            var stdoutTask = proc.StandardOutput.ReadToEndAsync();
            var stderrTask = proc.StandardError.ReadToEndAsync();

            // A healthy conversion of even a huge file finishes in minutes; an x2t stuck
            // on a malformed file never finishes. The generous default separates the two
            // without cutting legitimate work short.
            long timeoutMs = timeoutMinutes == 0 ? -1 : Math.Min((long)timeoutMinutes * 60_000, int.MaxValue);
            if (!proc.WaitForExit((int)timeoutMs))
            {
                try { proc.Kill(entireProcessTree: true); } catch { /* already gone */ }
                proc.WaitForExit();
                Console.Error.WriteLine($"{label}Error: conversion timed out after {timeoutMinutes} min " +
                                        "(--timeout <minutes> to adjust, 0 to disable)");
                return 3;
            }
            string stdout = stdoutTask.Result;
            string stderr = stderrTask.Result;

            if (proc.ExitCode != 0)
            {
                lock (ConsoleLock)
                {
                    Console.Error.WriteLine($"{label}x2t error (x2t exit code {proc.ExitCode})");
                    if (!string.IsNullOrWhiteSpace(stderr)) Console.Error.WriteLine(stderr);
                    if (!string.IsNullOrWhiteSpace(stdout)) Console.Error.WriteLine(stdout);
                }
                return 2;
            }

            if (verbose)
            {
                lock (ConsoleLock)
                {
                    if (!string.IsNullOrWhiteSpace(stdout)) Console.WriteLine(stdout);
                    if (!string.IsNullOrWhiteSpace(stderr)) Console.Error.WriteLine(stderr);
                }
            }

            if (!File.Exists(localOutput))
            {
                Console.Error.WriteLine($"{label}Error: conversion finished but the output file is missing");
                return 2;
            }

            if (stageOutput)
            {
                try
                {
                    File.Copy(localOutput, output, overwrite: true);
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"{label}Error: could not write output file ({output}): {ex.Message}");
                    return 1;
                }
            }

            Console.WriteLine($"{label}OK: {output}");
            return 0;
        }
        finally
        {
            // Best-effort: a stray handle on the work dir (antivirus scan, slow x2t child)
            // must not turn a finished conversion into a crash.
            try
            {
                if (Directory.Exists(workDir))
                    Directory.Delete(workDir, recursive: true);
            }
            catch { }
        }
    }

    // resources/, allfonts/ and custom-fonts/ live next to the exe when possible; when
    // that directory is not writable (e.g. C:\Program Files, /usr/local/bin), fall back
    // to the per-user data directory so the first run works out of the box.
    static string ResolveBaseDir(string exeDir)
    {
        if (IsWritableDir(exeDir)) return exeDir;
        string fallback = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Abx2t");
        Directory.CreateDirectory(fallback);
        Console.WriteLine($"Note: {exeDir} is not writable; components live in {fallback}");
        return fallback;
    }

    static bool IsWritableDir(string dir)
    {
        try
        {
            string probe = Path.Combine(dir, $".abx2t_probe_{Guid.NewGuid():N}");
            File.WriteAllText(probe, "");
            File.Delete(probe);
            return true;
        }
        catch
        {
            return false;
        }
    }

    // Exclusive lock file; FileShare.None maps to real locking on Windows and flock on
    // Unix. Released on dispose (or by the OS if the process dies).
    static FileStream AcquireStateLock(string path)
    {
        bool announced = false;
        while (true)
        {
            try
            {
                return new FileStream(path, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
            }
            catch (IOException)
            {
                if (!announced)
                {
                    Console.WriteLine("Another Abx2t instance is preparing components, waiting...");
                    announced = true;
                }
                Thread.Sleep(500);
            }
        }
    }

    static bool IsNetworkPath(string path)
    {
        if (path.StartsWith(@"\\", StringComparison.Ordinal)) return true;   // UNC
        if (!OperatingSystem.IsWindows()) return false;   // Unix network mounts are rare and indistinguishable; treat as local
        try
        {
            string? root = Path.GetPathRoot(path);
            return root != null && new DriveInfo(root).DriveType == DriveType.Network;
        }
        catch
        {
            return false;
        }
    }

    static int EnsureComponents(string resourcesDir, string x2tPath, string allfontsDir,
                                string allFonts, string fontsManifest, string customFontsDir)
    {
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

        // custom-fonts/ : extra fonts dropped in manually (no system install required),
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

        return 0;
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
    // MUST run synchronously, inside the preparation lock: while compact.exe holds a file
    // it cannot be executed or loaded (sharing violation) -- a fire-and-forget version
    // raced the first conversion and broke the x2t spawn (caught by CI on a fresh runner).
    static void TryCompressResources(string dir)
    {
        if (!OperatingSystem.IsWindows()) return;
        try
        {
            Console.WriteLine("Compressing resources (NTFS, one-time)...");
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
