const mongoose = require('mongoose');

const photoSchema = new mongoose.Schema({
    url: { type: String, default: '' },
    public_id: { type: String, default: '' },
});

const userSchema = new mongoose.Schema({
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    password: { type: String },
    firstName: { type: String, default: '' },
    lastName: { type: String, default: '' },
    username: { type: String, unique: true, sparse: true, default: undefined },
    usernameLastChangedAt: { type: Date, default: null },
    isDeleted: { type: Boolean, default: false },
    isPremium: { type: Boolean, default: false },
    premiumExpiration: { type: Date, default: null },
    height: Number,
    weight: Number,
    squatWeight: Number,
    deadliftWeight: Number,
    benchPressWeight: Number,
    gymTime: String,
    gymName: String,
    goal: { type: String, enum: ['Volumen', 'Definición', 'Mantenimiento'], default: 'Mantenimiento' },
    biography: { type: String, default: '' },
    gender: {
        type: String,
        enum: ['Masculino', 'Femenino', 'No Binario', 'Prefiero no decirlo', 'Otro', 'Pendiente'],
        default: 'Pendiente'
    },
    seeking: { type: [String], enum: ['Masculino', 'Femenino', 'No Binario', 'Prefiero no decirlo', 'Otro'], default: [] },
    relationshipGoal: { type: String, enum: ['Amistad', 'Relación', 'Casual', 'Otro', 'Pendiente'], default: 'Pendiente' },
    // Nuevos campos para verificación de correo:
    verificationCode: { type: String, default: null },
    isVerified: { type: Boolean, default: false },
    // Campos para usuarios temporales:
    isTemporary: { type: Boolean, default: false },
    registrationExpires: { type: Date, default: null },
    seenProfiles: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        default: [],
    }],
    likes: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    matches: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    blockedUsers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    age: { type: Number, default: 18 },
    profilePicture: { type: photoSchema, default: () => ({ url: '', public_id: '' }) },
    photos: { type: [photoSchema], default: [] },
    googleId: { type: String, unique: true, sparse: true },
    preferences: {
        ageRange: { min: { type: Number, default: 18 }, max: { type: Number, default: 99 } },
        distance: { type: Number, default: 50 },
        interests: { type: [String], default: [] }
    },
    location: {
        type: { type: String, enum: ['Point'], default: 'Point' },
        coordinates: { type: [Number], default: [0, 0] }
    },
    city: { type: String, default: '' },
    country: { type: String, default: '' },
    scrollCount: { type: Number, default: 0 },
    scrollLimitProfileId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    scrollLimitReachedAt: { type: Date, default: null },
}, { timestamps: true });

userSchema.index({ location: '2dsphere' });

module.exports = mongoose.model('User', userSchema);