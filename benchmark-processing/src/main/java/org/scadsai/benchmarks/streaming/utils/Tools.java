package org.scadsai.benchmarks.streaming.utils;

import org.apache.commons.io.IOUtils;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;

public class Tools {

    public static void StopStreamJob() throws Exception {
        System.out.println("Stream processing completed. Stopping the process.");
        //Maybe think about adding/triggering some checkpointing and metrics collection here
        throw new Exception("This is thrown intentionally to stop the job.");
    }

    public static File getMyResource(String resource, Class T) throws IOException {
        ClassLoader classLoader = T.getClassLoader();
        InputStream is = classLoader.getResourceAsStream(resource);
        File myFile = stream2file(is);
        return myFile;
    }

    // This is used to convert "stream input file" that is read from resources location (ip_address.mmdb) to "File"
    // The database is archived in the jar file itself. No need to provide them separately.
    public static File stream2file(InputStream in) throws IOException {
        final File tempFile = File.createTempFile("stream2file", ".tmp");
        tempFile.deleteOnExit();
        try (FileOutputStream out = new FileOutputStream(tempFile)) {
            IOUtils.copy(in, out);
        }
        return tempFile;
    }

    public static boolean deleteDirectory(File directoryToBeDeleted) {
        File[] allContents = directoryToBeDeleted.listFiles();
        if (allContents != null) {
            for (File file : allContents) {
                deleteDirectory(file);
            }
        }
        return directoryToBeDeleted.delete();
    }

    public static double roundOfThree(double value) {
        return Math.round(value * 1000) / 1000;
    }
}
