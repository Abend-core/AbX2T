using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Xml;

class Program
{
    // Formats lus par ONLYOFFICE dans ce bundle (word/cell/slide/visio/pdf + DLLs x2t/bin, voir
    // convert/docs/SUPPORTED_FORMATS.md). Formats ecrits : sous-ensemble reellement inscriptible
    // (les formats legacy binaires et e-book/scan sont lus mais jamais reecrits par ONLYOFFICE).
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
        if (args.Length < 2)
        {
            Console.Error.WriteLine("Usage: Abx2t.exe <source> <sortie>");
            Console.Error.WriteLine($"  Entree acceptee : .{string.Join(", .", InputExtensions)}");
            Console.Error.WriteLine($"  Sortie acceptee : .{string.Join(", .", OutputExtensions)}");
            return 1;
        }

        string input  = Path.GetFullPath(args[0]);
        string output = Path.GetFullPath(args[1]);

        if (!File.Exists(input))
        {
            Console.Error.WriteLine($"Erreur: fichier source introuvable: {input}");
            return 1;
        }

        string inputExt = Path.GetExtension(input).ToLowerInvariant().TrimStart('.');
        if (Array.IndexOf(InputExtensions, inputExt) < 0)
        {
            Console.Error.WriteLine($"Erreur: format non supporte (.{inputExt}). " +
                                     $"Formats acceptes: .{string.Join(", .", InputExtensions)}");
            return 1;
        }

        string outputExt = Path.GetExtension(output).ToLowerInvariant().TrimStart('.');
        if (Array.IndexOf(OutputExtensions, outputExt) < 0)
        {
            Console.Error.WriteLine($"Erreur: sortie non supportee (.{outputExt}). " +
                                     $"Formats acceptes: .{string.Join(", .", OutputExtensions)}");
            return 1;
        }

        string exeDir       = AppContext.BaseDirectory;
        string resourcesDir = Path.Combine(exeDir, "resources");
        string allfontsDir  = Path.Combine(exeDir, "allfonts");
        string x2tPath      = Path.Combine(resourcesDir, "x2t.exe");
        string allFonts     = Path.Combine(allfontsDir, "AllFonts.js");

        // Extraction des assets si absents (x2t.exe, DLLs, allfontsgen.exe, sdkjs -> resources/)
        if (!File.Exists(x2tPath))
        {
            Console.WriteLine("Premiere utilisation : extraction des composants...");
            int r = ExtractAssets(resourcesDir);
            if (r != 0) return r;
            Console.WriteLine("Extraction OK.");
        }

        // Generation AllFonts.js si absent (specifique a la machine -> allfonts/)
        if (!File.Exists(allFonts))
        {
            Console.WriteLine("Generation des polices systeme...");
            int r = GenerateFonts(resourcesDir, allfontsDir, allFonts);
            if (r != 0) return r;
            Console.WriteLine("Polices OK.");
        }

        string sdkjsDir = Path.Combine(resourcesDir, "sdkjs");
        string? outputDir = Path.GetDirectoryName(output);
        if (!string.IsNullOrEmpty(outputDir))
            Directory.CreateDirectory(outputDir);

        // Dossier de travail local (TEMP systeme) : x2t lit/ecrit uniquement en local,
        // meme si la source ou la destination reelle est sur un partage reseau (\\serveur\partage
        // ou un lecteur mappe). Ca evite les problemes de verrous/latence/ecriture partielle
        // sur le reseau, et garantit qu'un plantage ne laisse rien sur le partage.
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
                Console.Error.WriteLine($"Erreur: lecture du fichier source impossible ({input}): {ex.Message}");
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

            if (!File.Exists(localOutput))
            {
                Console.Error.WriteLine("Erreur: conversion terminee mais fichier de sortie absent");
                return 1;
            }

            try
            {
                File.Copy(localOutput, output, overwrite: true);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Erreur: ecriture du fichier de sortie impossible ({output}): {ex.Message}");
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

    static int GenerateFonts(string resourcesDir, string allfontsDir, string allFontsPath)
    {
        string allfontsgen = Path.Combine(resourcesDir, "allfontsgen.exe");
        if (!File.Exists(allfontsgen))
        {
            Console.Error.WriteLine($"Erreur: allfontsgen.exe introuvable dans {resourcesDir}");
            return 1;
        }

        Directory.CreateDirectory(allfontsDir);

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
                WorkingDirectory = resourcesDir,
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
            File.Copy($"{tmp}\\font_selection.bin",  Path.Combine(allfontsDir, "font_selection.bin"), overwrite: true);

            string sdkCommon = Path.Combine(resourcesDir, "sdkjs", "common");
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
