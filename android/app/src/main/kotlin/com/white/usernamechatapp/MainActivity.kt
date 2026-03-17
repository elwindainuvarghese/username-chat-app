package com.white.usernamechatapp

import android.os.Bundle
import android.view.WindowManager
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import android.widget.LinearLayout
import android.graphics.Color
import android.view.Gravity
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    private var overlay: View? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Prevent screenshots and screen recording, hide preview in recent apps
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        
        // Create an overlay programmatically
        createOverlay()
    }
    
    private fun createOverlay() {
        val dpToPx = resources.displayMetrics.density
        
        val frameLayout = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.BLACK)
            visibility = View.GONE
            // Set elevation so it shows above other views
            elevation = 100f
        }
        
        val linearLayout = LinearLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER
            )
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }
        
        val imageView = ImageView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                (50 * dpToPx).toInt(), (50 * dpToPx).toInt()
            )
            setImageResource(android.R.drawable.ic_secure) // Built-in system lock icon
        }
        
        val textView = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, (10 * dpToPx).toInt(), 0, 0)
            }
            text = "App content hidden"
            setTextColor(Color.WHITE)
            textSize = 16f
        }
        
        linearLayout.addView(imageView)
        linearLayout.addView(textView)
        frameLayout.addView(linearLayout)
        
        // Add overlay to activity window
        addContentView(frameLayout, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))
        
        overlay = frameLayout
    }

    override fun onPause() {
        super.onPause()
        overlay?.visibility = View.VISIBLE
    }

    override fun onResume() {
        super.onResume()
        overlay?.visibility = View.GONE
    }
}