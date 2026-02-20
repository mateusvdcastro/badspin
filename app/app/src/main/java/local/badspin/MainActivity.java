package local.badspin;

import androidx.annotation.RequiresApi;
import androidx.appcompat.app.AppCompatActivity;

import android.os.Build;
import android.os.Bundle;
import android.text.method.ScrollingMovementMethod;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

import java.io.IOException;
import java.nio.file.FileSystem;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;

public class MainActivity extends AppCompatActivity {
    public static final String TAG = "BADSPIN_APP";
    public static final String soName = "libbadspin.so";
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        final Button button = (Button) findViewById(R.id.button);
        button.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                String dataDir = getApplicationInfo().dataDir;
                String outputFile = dataDir + "/" + soName;
                try {
                    // First, let's check if the asset exists
                    String[] assets = getAssets().list("");
                    Log.i(TAG, "Available assets: " + java.util.Arrays.toString(assets));
                    
                    // Try to open the asset
                    Log.i(TAG, "Attempting to open asset: " + soName);
                    Files.copy(getAssets().open(soName),
                                Paths.get(outputFile),
                                StandardCopyOption.REPLACE_EXISTING);
                    Log.i(TAG, "Successfully copied " + soName + " to " + outputFile);
                } catch (IOException e) {
                    Log.e(TAG, "Failed to copy asset: " + e.getMessage());
                    e.printStackTrace();
                    throw new RuntimeException(e);
                }
                String cmd = "LD_LIBRARY_PATH=" + dataDir +
                             " LD_PRELOAD=" + outputFile +
                             " sleep 1";
                Log.i(TAG, "Running " + soName);
                Process process = null;
                try {
                    // just start the process, don't wait for it in the onClick listener
                    process = new ProcessBuilder("sh", "-c", cmd).redirectErrorStream(true).start();
//                    process.waitFor();
                } catch (IOException e) {
                    throw new RuntimeException(e);
                }

                // Log.i(TAG, "Done. " + process.exitValue());
            }
        });
    }
}