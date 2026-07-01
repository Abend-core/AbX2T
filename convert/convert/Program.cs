using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Xml;

class Program
{
    static int Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.Error.WriteLine("Usage: Abx2t.exe <source.docx|source.doc> <output.pdf>");
            return 1;
        }

        string input  = Path.GetFullPath(args[0]);
        string output = Path.GetFullPath(args[1]);

        if (!File.Exists(input))
        {
            Console.Error.WriteLine($"Erreur: fichier source introuvable: {input}");
            return 1;
        }

        string inputExt = Path.GetExtension(input).ToLowerInvariant();
        if (inputExt != ".docx" && inputExt != ".doc")
        {
            Console.Error.WriteLine($"Erreur: format non supporte ({inputExt}). Utiliser .doc ou .docx");
            return 1;
        }

        if (Path.GetExtension(output).ToLowerInvariant() != ".pdf")
        {
            Console.Error.WriteLine("Erreur: la sortie doit etre un .pdf");
            return 1;
        }

        string exeDir  = AppContext.BaseDirectory;
        string x2tPath = Path.Combine(exeDir, "x2t.exe");
        string allFonts = Path.Combine(exeDir, "AllFonts.js");

        // Extraction des assets si absents
        if (!File.Exists(x2tPath))
        {
            Console.WriteLine("Premiere utilisation : extraction des composants...");
            int r = ExtractAssets(exeDir);
            if (r != 0) return r;
            Console.WriteLine("Extraction OK.");
        }

        // Generation AllFonts.js si absent
        if (!File.Exists(allFonts))
        {
            Console.WriteLine("Generation des polices systeme...");
            int r = GenerateFonts(exeDir, allFonts);
            if (r != 0) return r;
            Console.WriteLine("Polices OK.");
        }

        string sdkjsDir = Path.Combine(exeDir, "sdkjs");
        string? outputDir = Path.GetDirectoryName(output);
        if (!string.IsNullOrEmpty(outputDir))
            Directory.CreateDirectory(outputDir);

        string configPath = Path.Combine(Path.GetTempPath(), $"x2t_{Guid.NewGuid():N}.xml");
        try
        {
            WriteConfig(configPath, input, output, allFonts, exeDir, sdkjsDir);

            var psi = new ProcessStartInfo
            {
                FileName               = x2tPath,
                Arguments              = $"\"{configPath}\"",
                WorkingDirectory       = exeDir,
                UseShellExecute        = false,
                RedirectStandardOutput = true,
                RedirectStandardError  = true,
            };

            using var proc = Process.Start(psi)!;
            string stdout = proc.StandardOutput.ReadToEnd();
            string stderr = proc.StandardError.ReadToEnd();
            proc.WaitForExit();

            if (proc.ExitCode != 0)
            {
                Console.Error.WriteLine($"Erreur x2t (code {proc.ExitCode})");
                if (!string.IsNullOrWhiteSpace(stderr)) Console.Error.WriteLine(stderr);
                if (!string.IsNullOrWhiteSpace(stdout)) Console.Error.WriteLine(stdout);
                return proc.ExitCode;
            }

            if (!File.Exists(output))
            {
                Console.Error.WriteLine("Erreur: conversion terminee mais PDF absent");
                return 1;
            }

            Console.WriteLine($"OK: {output}");
            return 0;
        }
        finally
        {
            if (File.Exists(configPath))
                File.Delete(configPath);
        }
    }

    static int ExtractAssets(string destDir)
    {
        try
        {
            using Stream? zip = Assembly.GetExecutingAssembly()
                .GetManifestResourceStream("convert.assets.zip");
            if (zip == null)
            {
                Console.Error.WriteLine("Erreur: assets.zip introuvable dans l'executable");
                return 1;
            }
            using var archive = new ZipArchive(zip, ZipArchiveMode.Read);
            archive.ExtractToDirectory(destDir, overwriteFiles: true);
            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Erreur extraction: {ex.Message}");
            return 1;
        }
    }

    static int GenerateFonts(string exeDir, string allFontsPath)
    {
        string allfontsgen = Path.Combine(exeDir, "allfontsgen.exe");
        if (!File.Exists(allfontsgen))
        {
            Console.Error.WriteLine($"Erreur: allfontsgen.exe introuvable dans {exeDir}");
            return 1;
        }

        string tmp = Path.Combine(Path.GetTempPath(), $"fonts_{Guid.NewGuid():N}");
        Directory.CreateDirectory(tmp);
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName         = allfontsgen,
                Arguments        = $"--use-system=true --use-system-user-fonts=true " +
                                   $"\"--selection={tmp}\\font_selection.bin\" " +
                                   $"\"--allfonts={tmp}\\AllFonts.js\" " +
                                   $"\"--allfonts-web={tmp}\\AllFonts2.js\" " +
                                   $"\"--output-web={tmp}\"",
                WorkingDirectory = exeDir,
                UseShellExecute  = false,
            };
            using var proc = Process.Start(psi)!;
            proc.WaitForExit();
            if (proc.ExitCode != 0)
            {
                Console.Error.WriteLine($"Erreur allfontsgen (code {proc.ExitCode})");
                return 1;
            }

            File.Copy($"{tmp}\\AllFonts.js",        allFontsPath, overwrite: true);
            File.Copy($"{tmp}\\font_selection.bin",  Path.Combine(exeDir, "font_selection.bin"), overwrite: true);

            string sdkCommon = Path.Combine(exeDir, "sdkjs", "common");
            if (Directory.Exists(sdkCommon))
                File.Copy($"{tmp}\\AllFonts.js", Path.Combine(sdkCommon, "AllFonts.js"), overwrite: true);

            return 0;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Erreur generation polices: {ex.Message}");
            return 1;
        }
        finally
        {
            Directory.Delete(tmp, recursive: true);
        }
    }

    static void WriteConfig(string config, string input, string output,
                            string allFonts, string fontDir, string sdkjsDir)
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
        w.WriteEndElement();
        w.WriteEndDocument();
    }
}
