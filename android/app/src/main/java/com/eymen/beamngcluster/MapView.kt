package com.eymen.beamngcluster

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.util.AttributeSet
import android.view.View
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

class MapView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    data class Pt(val x: Float, val y: Float)

    private val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0x225EE7FF
        strokeWidth = 1f
        style = Paint.Style.STROKE
    }
    private val trailPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xAA5EE7FF.toInt()
        strokeWidth = 3f
        style = Paint.Style.STROKE
    }
    private val routePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xCC3DFFB0.toInt()
        strokeWidth = 3f
        style = Paint.Style.STROKE
        pathEffect = android.graphics.DashPathEffect(floatArrayOf(12f, 10f), 0f)
    }
    private val carPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFF5EE7FF.toInt()
        style = Paint.Style.FILL
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFF7F8FA3.toInt()
        textAlign = Paint.Align.CENTER
        textSize = 28f
    }

    private var trail: List<Pt> = emptyList()
    private var carX = 0f
    private var carY = 0f
    private var yaw = 0f
    private var speedMs = 0f
    private var hasFix = false

    fun update(x: Float, y: Float, yawRad: Float, speed: Float, points: List<Pt>) {
        hasFix = true
        carX = x
        carY = y
        yaw = yawRad
        speedMs = speed
        trail = points
        invalidate()
    }

    fun clear() {
        hasFix = false
        trail = emptyList()
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        var x = 0f
        while (x < w) {
            canvas.drawLine(x, 0f, x, h, gridPaint)
            x += 28f
        }

        if (!hasFix) {
            canvas.drawText("harita bekleniyor", w / 2f, h / 2f, textPaint)
            return
        }

        var minX = carX
        var maxX = carX
        var minY = carY
        var maxY = carY
        for (p in trail) {
            minX = minOf(minX, p.x); maxX = maxOf(maxX, p.x)
            minY = minOf(minY, p.y); maxY = maxOf(maxY, p.y)
        }
        val ahead = 50f + speedMs * 3f
        val route = ArrayList<Pt>(8)
        for (i in 1..8) {
            val d = ahead * i / 8f
            route += Pt(carX + sin(yaw) * d, carY + cos(yaw) * d)
        }
        for (p in route) {
            minX = minOf(minX, p.x); maxX = maxOf(maxX, p.x)
            minY = minOf(minY, p.y); maxY = maxOf(maxY, p.y)
        }
        val span = max(40f, max(maxX - minX, maxY - minY)) * 1.3f
        val cx = (minX + maxX) / 2f
        val cy = (minY + maxY) / 2f
        val sc = minOf((w - 40f) / span, (h - 40f) / span)
        fun tx(v: Float) = w / 2f + (v - cx) * sc
        fun ty(v: Float) = h / 2f - (v - cy) * sc

        if (trail.size > 1) {
            val path = Path()
            path.moveTo(tx(trail[0].x), ty(trail[0].y))
            for (i in 1 until trail.size) path.lineTo(tx(trail[i].x), ty(trail[i].y))
            canvas.drawPath(path, trailPaint)
        }
        val rpath = Path()
        rpath.moveTo(tx(carX), ty(carY))
        for (p in route) rpath.lineTo(tx(p.x), ty(p.y))
        canvas.drawPath(rpath, routePaint)

        canvas.save()
        canvas.translate(tx(carX), ty(carY))
        canvas.rotate((-yaw) * 180f / Math.PI.toFloat())
        val car = Path()
        car.moveTo(0f, -12f)
        car.lineTo(8f, 12f)
        car.lineTo(0f, 6f)
        car.lineTo(-8f, 12f)
        car.close()
        canvas.drawPath(car, carPaint)
        canvas.restore()
    }
}
